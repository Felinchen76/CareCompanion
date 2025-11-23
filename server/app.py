from flask import Flask, request, jsonify
from flask_cors import CORS
import os, io, json, tempfile
from datetime import datetime

# libs for extraction
try:
    import fitz  # PyMuPDF
except Exception:
    fitz = None
try:
    import docx
except Exception:
    docx = None
try:
    from PIL import Image
    import pytesseract
except Exception:
    Image = None
    pytesseract = None

# dotenv (optional)
from dotenv import load_dotenv
load_dotenv()

OPENAI_KEY = os.environ.get("OPENAI_API_KEY")
if not OPENAI_KEY:
    print("WARNING: OPENAI_API_KEY not set. Set it in server/.env for real analysis.")

app = Flask(__name__)
CORS(app)

def extract_text_from_bytes(filename: str, data: bytes) -> str:
    name = filename.lower()
    # pdf
    if name.endswith('.pdf') and fitz:
        text = []
        doc = fitz.open(stream=data, filetype='pdf')
        for p in doc:
            text.append(p.get_text())
        return "\n".join(text)
    # docx
    if name.endswith('.docx') and docx:
        document = docx.Document(io.BytesIO(data))
        return "\n".join(p.text for p in document.paragraphs)
    # images -> OCR
    if any(name.endswith(ext) for ext in ('.png', '.jpg', '.jpeg', '.tiff', '.bmp')) and pytesseract and Image:
        img = Image.open(io.BytesIO(data))
        return pytesseract.image_to_string(img, lang='deu+eng')
    # fallback: try decode
    try:
        return data.decode('utf-8', errors='ignore')
    except:
        return ''

def call_openai_extract(text: str) -> dict:
    # Minimal wrapper using OpenAI chat completions
    import requests
    system = (
        "Du bist ein medizinisch-orientierter Assistent. "
        "Extrahiere aus dem folgenden Text strukturierte JSON: "
        "dates (ISO), medications (name,dose), followUps (keywords), actions (title,description,optional date). "
        "Gib nur JSON zurück."
    )
    user = f"Dokumenttext:\n{text[:40000]}"
    payload = {
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user}
        ],
        "temperature": 0.0,
        "max_tokens": 1200
    }
    headers = {"Authorization": f"Bearer {OPENAI_KEY}", "Content-Type": "application/json"}
    r = requests.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    j = r.json()
    content = j["choices"][0]["message"]["content"]
    try:
        parsed = json.loads(content)
    except Exception:
        parsed = {"raw": content}
    return parsed

@app.route("/api/extract", methods=["POST"])
def api_extract():
    # Accept file upload or raw text
    text = ""
    if 'file' in request.files:
        f = request.files['file']
        filename = f.filename or f"upload_{datetime.utcnow().timestamp()}"
        data = f.read()
        text = extract_text_from_bytes(filename, data)
    else:
        text = request.form.get('text', '') or request.json.get('text', '')

    if not text:
        return jsonify({"error": "no text extracted"}), 400

    # If OPENAI_KEY not set, return only extracted text
    if not OPENAI_KEY:
        return jsonify({"text": text, "analysis": {"raw": "OPENAI_API_KEY not configured on server"}})

    try:
        analysis = call_openai_extract(text)
        print(f"[OpenAI Analysis] {json.dumps(analysis, indent=2, ensure_ascii=False)}")
    except Exception as e:
        return jsonify({"text": text, "error": str(e)}), 500

    return jsonify({"text": text, "analysis": analysis})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)