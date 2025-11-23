# CareCompanion

**Your Intelligent Assistant for Home Care**

CareCompanion is an innovative application designed to revolutionize the organizational tasks of family caregivers. Our goal is to provide individuals and caregiving teams with a user-friendly platform that automates the analysis and management of medical documents, appointments, and tasks.

--

## Vision

Home care often means keeping track of medications, doctor's appointments, prescriptions, and medical documentation—a time-consuming and error-prone task. CareCompanion takes this burden off your shoulders with:

- **Automatic Document Analysis**: Upload a doctor's letter → AI extracts medications, appointments, and recommendations
- **Proactive Agent**: Monitors medication inventories, sends reminders, and learns recurring patterns
- **Centralized Management**: All information in one place—medications, tasks, appointments, documents

---

## Implemented Features

### Intelligent Document Processing
- **Multi-Format Support**: PDFs (PyMuPDF), Images (Tesseract OCR)
- **AI Analysis**: OpenAI GPT-4o Mini extracts structured data:
  - Medications (Name, Dosage)
  - Appointments (Date, Type)
  - Action Recommendations (e.g., "Reorder Prescription")

- **Automatic Task Generation**: Tasks are created directly from analyzed documents

### Proactive Agent
- **24/7 Monitoring**: Runs in the background and checks every 10 seconds:
  - Low medication stocks → Creates a "Reorder prescription" task
  - Upcoming appointments → Reminder 1 day in advance
  - New documents → Automatic analysis
- **Time series learning**: Recognizes recurring appointments (e.g., dentist every 6 months) and predicts the next appointment
- **Quiet hours management**: No notifications between 10:00 PM and 7:00 AM

### Dashboard & Administration
- **Live statistics**: Open tasks, medication levels, upcoming appointments
- **Medication overview**: Color-coded warning for low stock (<10 medications)
- **Task management**: To-do list with due dates
- **Document archive**: All uploaded medical letters/reports in one place

### Multimodal interaction
- **Text-to-speech**: Agent can read reminders aloud
- **Speech-to-Text**: Create notes using voice input
- **Cross-Platform**: Web, iOS, Android (Flutter)

---

## Technology Stack

### Frontend
- **Flutter 3.5+**: Cross-Platform UI (Web, iOS, Android)
- **Dart**: Programming Language
- **Packages**:

- `file_picker`: Document Upload
- `speech_to_text`: Speech Input
- `flutter_tts`: Speech Output
- `shared_preferences`: Local Data Persistence
- `http`: REST API Communication

### Backend
- **Flask 3.0**: Python Web Framework
- **OpenAI API**: GPT-4o Mini for NLP Analysis
- **PyMuPDF**: PDF Text Extraction
- **Tesseract OCR**: Text Recognition in Images (German)
- **python-dotenv**: Environment Variable Management

### AI/ML
- **OpenAI GPT-4o Mini**: Structured Data Extraction from Medical Texts
- **Time series analysis**: Median-based prediction of recurring events (Python)
---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                      Flutter Frontend                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │Dashboard │  │Medication|  │ Tasks    │  │Documents │    │
│  │          │  │          │  │          │  │          │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           AgentService (Dart)                        │  │
│  │  • 10s Loop: Check Medication, Appointments, Docs    │  │
│  │  • Learn Time Series  (Recurrence-Analyse)           │  │
│  │  • Task-Management                                   │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
                            │ HTTP/REST
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Flask Backend                          │
│  POST /analyze                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  1. Received document (PDF/image)                    │   │
│  │  2. Extract text (PyMuPDF/Tesseract)                 │   │
│  │  3. OpenAI API: Extract structured data              │   │
│  │     → medications: [{name, dose}, ...]               │   │
│  │     → dates: [ISO-String, ...]                       │   │
│  │     → actions: [{title, description, date}, ...]     │   │
│  │  4. Send back    JSON                                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    OpenAI GPT-4o Mini
```

### Data Flow: Document Upload

1. **User** uploads a doctor's letter (PDF/image) via the Flutter app

2. **Frontend** sends the file to the backend via `POST /analyze`

3. **Backend** extracts the text:

- PDF → PyMuPDF

- Image → Tesseract OCR (German)

4. **Backend** sends the text and prompt to the OpenAI API

5. **OpenAI** analyzes the text and returns JSON:

``json

{
"medications": [{"name": "Aspirin", "dose": "100mg"}],

"dates": ["2025-12-07"],

"actions": [
{"title": "Reorder prescription for aspirin", "date": "2025-11-30"},

{"title": "Attend follow-up appointment", "date": "2025-12-07"}

]

` ... }
   ```
6. **Frontend** displays suggestions in dialogue
7. **User** accepted → Tasks are created and displayed in the dashboard

### Data Flow: Proactive Agent

```
┌─────────────────────────────────────────────────────────┐
│  AgentService._agentLoop() (every 10s)                  │
│                                                         │
│  1. Rest period? (22:00-07:00) → Break                  │
│  2. Check Medicin:                                      │
│     • amountLeft < 10 → Task "Reorder prescription"     │
│  3. Check Appointments:                                 │
│     • Appointment in <24h → create Reminder             │
│  4. Check Documents:                                    │
│     • New Protocoll/Document → analyze automatically    │
│  5. Time Series Analysis:                               │
│     • ≥3 similar appointments → Median-Intervall        │
│     • predict / suggest next appointment                │
└─────────────────────────────────────────────────────────┘
```

## Installation & Setup

### Requirements
- **Flutter SDK** (≥3.5.0): [Installationsanleitung](https://docs.flutter.dev/get-started/install)
- **Python** (≥3.10): [python.org](https://python.org)
- **Tesseract OCR**: [Windows Installer](https://github.com/UB-Mannheim/tesseract/wiki)
- **OpenAI API Key**: [platform.openai.com](https://platform.openai.com)

### 1. Clone Repository 
```bash
git clone https://github.com/dein-username/CareCompanion.git
cd CareCompanion
```

### 2. Backend einrichten
```bash
cd server

# create Virtual Environment
python -m venv .venv
.venv\Scripts\activate  # Windows
# source .venv/bin/activate  # macOS/Linux

# install Dependencies
pip install -r requirements.txt

# create .env file with API key
echo OPENAI_API_KEY=sk-proj-your-key-here > .env

# check Tesseract-Path (in app.py Row 20)
# Standard: C:\Program Files\Tesseract-OCR\tesseract.exe

# start Server
python app.py
```

**Expected Output:**
```
[Backend] Registered routes:
  analyze: /analyze [POST, OPTIONS]
  health: /health [GET, HEAD, OPTIONS]
[Backend] Starting CareCompanion Backend...
[Backend] OpenAI API Key: ✓ Set
 * Running on http://127.0.0.1:5000
```

### 3. Start Frontend
```bash
cd ../carecompanion_app

# Dependencies installieren
flutter pub get

# Web-Version starten
flutter run -d chrome

# Oder Mobile (Emulator/Device muss laufen)
flutter run
```

---

## Usage

### Upload & Analyze Documents

1. Open the **Logs** tab

2. Click the **"+"** (floating action button)

3. Select PDF or image
4. Wait for analysis (~5-10s)

5. Review suggested tasks in the dialog

6. Click **"Create Tasks"**

7. Tasks appear in the dashboard

### Check Agent Status
- **Dashboard**: Green icon in the app bar = Agent is running
- **Logs**: Chrome DevTools Console (`F12`)

```

[Agent] Loop tick...

[Agent] Checking medications...

[Agent] Created task: Reorder prescription for aspirin

```

### Manage Medications
- Open the **Medications** tab

- Low stock (<10) = Orange badge

- Critical (<5) = Red border + "Critical!" Badge

- Click on card → Detailed view with "Request prescription"

---

## Test demo data

The app automatically loads demo data (`assets/data/dummy_data.json`) upon startup:

- 3 medications (1x low stock)
- 2 appointments (1x in the future)
- 1 task

**Test with your own document:**
Create `test.txt` with:

```
Doctor's letter dated November 23, 2025

Patient: Max Mustermann
Diagnosis: Hypertension

Medication:

- Aspirin 100mg, once daily
- Ramipril 5mg, in the morning

Check-up recommended in 2 weeks.

```

Upload → should extract 2 medications + 1 appointment + 3 actions

---

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. Create a **Feature Branch**: `git checkout -b feature/awesome-feature`
3. **Commit** your changes: `git commit -m 'Add awesome feature'`
4. **Push** the branch: `git push origin feature/awesome-feature`
5. Open a **Pull Request**

## Contact

In Case of any Questions or Problems:
- **Issues**: [GitHub Issues](https://github.com/dein-username/CareCompanion/issues)

**Developed with ❤️ for people in need of care and their relatives**

Developed by Anna-Carina Gehlisch & Felicitas Lock
HACKATUM '25 Group Name: CareCompanion
