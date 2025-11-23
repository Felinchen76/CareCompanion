from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from openai import OpenAI
from dotenv import load_dotenv
import fitz  # PyMuPDF
import pytesseract
from PIL import Image
import io

load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# OpenAI client
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Configure Tesseract path (Windows)
# Adjust path if tesseract is installed elsewhere
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


def extract_text_from_pdf(file_bytes: bytes) -> str:
    """Extract text from PDF using PyMuPDF"""
    try:
        doc = fitz.open(stream=file_bytes, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text()
        doc.close()
        return text.strip()
    except Exception as e:
        print(f"[PDF Extract Error] {e}")
        return ""


def extract_text_from_image(file_bytes: bytes) -> str:
    """Extract text from image using Tesseract OCR"""
    try:
        image = Image.open(io.BytesIO(file_bytes))
        text = pytesseract.image_to_string(image, lang='deu')  # German language
        return text.strip()
    except Exception as e:
        print(f"[OCR Extract Error] {e}")
        return ""


def call_openai_extract(text: str) -> dict:
    """
    Use OpenAI Chat API to extract structured medical data from text
    Returns: dict with keys: dates, medications, actions, raw
    """
    system = """Du bist ein medizinischer Assistent für Pflegedokumentation.
Extrahiere aus dem Text strukturierte Daten im JSON-Format:

{
  "dates": ["ISO-Datum", ...],
  "medications": [{"name": "string", "dose": "string"}, ...],
  "actions": [{"title": "string", "description": "string", "date": "ISO-Datum"}, ...]
}

REGELN:
1. Für jedes Medikament: erstelle action "Rezept für [Name] nachbestellen"
2. Für jeden Termin: erstelle action "Termin am [Datum] wahrnehmen"
3. Für Kontrollen/Nachsorge: erstelle action mit konkretem Titel
4. Datum im Format YYYY-MM-DD
5. Wenn keine Aktionen ableitbar: nutze "Dokument manuell prüfen"

Beispiel Input: "Patient nimmt Aspirin 100mg. Kontrolle in 2 Wochen."
Beispiel Output:
{
  "dates": ["2025-12-07"],
  "medications": [{"name": "Aspirin", "dose": "100mg"}],
  "actions": [
    {"title": "Rezept für Aspirin nachbestellen", "description": "Bestand prüfen", "date": "2025-11-30"},
    {"title": "Kontrolltermin wahrnehmen", "description": "In 2 Wochen", "date": "2025-12-07"}
  ]
}

Gib NUR JSON zurück, keine Erklärungen."""

    user_prompt = f"Extrahiere Daten aus folgendem Text:\n\n{text}"

    try:
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.1,
            max_tokens=800
        )
        content = response.choices[0].message.content.strip()
        
        # Remove markdown code blocks if present
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]
        
        parsed = json.loads(content)
        
        # Ensure all required keys exist
        if 'actions' not in parsed:
            parsed['actions'] = []
        if 'medications' not in parsed:
            parsed['medications'] = []
        if 'dates' not in parsed:
            parsed['dates'] = []
        if 'raw' not in parsed:
            parsed['raw'] = text[:500]
        
        print(f"[OpenAI] Extracted: {json.dumps(parsed, indent=2, ensure_ascii=False)}")
        return parsed

    except json.JSONDecodeError as e:
        print(f"[OpenAI] JSON parse error: {e}, raw: {content}")
        return {"raw": text[:500], "actions": [], "medications": [], "dates": [], "error": str(e)}
    except Exception as e:
        print(f"[OpenAI] Error: {e}")
        return {"raw": text[:500], "actions": [], "medications": [], "dates": [], "error": str(e)}


@app.route('/analyze', methods=['POST'])
def analyze():
    """
    Endpoint to analyze uploaded medical documents
    Expects: multipart/form-data with 'file' field
    Returns: JSON with extracted data
    """
    try:
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file provided'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'Empty filename'}), 400
        
        # Read file bytes
        file_bytes = file.read()
        filename_lower = file.filename.lower()
        
        # Extract text based on file type
        extracted_text = ""
        
        if filename_lower.endswith('.pdf'):
            print(f"[Backend] Processing PDF: {file.filename}")
            extracted_text = extract_text_from_pdf(file_bytes)
        elif filename_lower.endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff')):
            print(f"[Backend] Processing Image: {file.filename}")
            extracted_text = extract_text_from_image(file_bytes)
        elif filename_lower.endswith(('.doc', '.docx')):
            # For DOCX, would need python-docx library
            return jsonify({'success': False, 'error': 'DOCX not supported yet'}), 400
        else:
            return jsonify({'success': False, 'error': f'Unsupported file type: {file.filename}'}), 400
        
        if not extracted_text or len(extracted_text) < 10:
            return jsonify({
                'success': False, 
                'error': 'Could not extract text from document (empty or too short)'
            }), 400
        
        print(f"[Backend] Extracted text length: {len(extracted_text)}")
        print(f"[Backend] First 200 chars: {extracted_text[:200]}")
        
        # Analyze with OpenAI
        analysis = call_openai_extract(extracted_text)
        print(f"[Backend] Analysis complete: {json.dumps(analysis, indent=2, ensure_ascii=False)}")
        
        return jsonify({
            'success': True,
            'analysis': analysis
        })
    
    except Exception as e:
        print(f"[Backend] Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'service': 'CareCompanion Backend'})


# Debug: print all registered routes
with app.app_context():
    print("[Backend] Registered routes:")
    for rule in app.url_map.iter_rules():
        print(f"  {rule.endpoint}: {rule.rule} [{', '.join(rule.methods)}]")

if __name__ == '__main__':
    print("[Backend] Starting CareCompanion Backend...")
    print(f"[Backend] OpenAI API Key: {'✓ Set' if os.getenv('OPENAI_API_KEY') else '✗ Missing'}")
    app.run(debug=True, host='127.0.0.1', port=5000)