// ...existing code...
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/task.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/medical_note.dart' as mednote;
import '../models/patient.dart'; // PatientProfile usw.
import '../models/user.dart'; // PatientProfile usw.


class AgentService {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isRunning = false;

  // Ruhezeiten
  int quietFromHour;
  int quietToHour;

  // Datenmodelle
  late UserProfile user;
  late PatientProfile patient;

  AgentService({this.quietFromHour = 22, this.quietToHour = 7});

  // ----------------------------------------------------
  // LOAD DATA (Dummy)
  // ----------------------------------------------------
  Future<void> loadDummyData() async {
    final String jsonStr = await rootBundle.loadString('assets/data/dummy_data.json');
    final Map<String, dynamic> jsonData = json.decode(jsonStr);

    user = UserProfile.fromJson(jsonData['userProfile'] ?? <String, dynamic>{});
    patient = PatientProfile.fromJson(jsonData['patientProfile'] ?? <String, dynamic>{});
  }

  // ----------------------------------------------------
  // Ruhezeiten
  // ----------------------------------------------------
  void setQuietHours(int fromHour, int toHour) {
    quietFromHour = fromHour % 24;
    quietToHour = toHour % 24;
  }

  bool _isWithinQuietHours(DateTime dt) {
    final h = dt.hour;
    if (quietFromHour == quietToHour) return false;
    if (quietFromHour < quietToHour) return h >= quietFromHour && h < quietToHour;
    return h >= quietFromHour || h < quietToHour;
  }

  Duration _timeUntilActive(DateTime dt) {
    if (!_isWithinQuietHours(dt)) return Duration.zero;
    DateTime end;
    if (quietFromHour < quietToHour) {
      end = DateTime(dt.year, dt.month, dt.day, quietToHour);
    } else {
      if (dt.hour >= quietFromHour) {
        end = DateTime(dt.year, dt.month, dt.day + 1, quietToHour);
      } else {
        end = DateTime(dt.year, dt.month, dt.day, quietToHour);
      }
    }
    return end.difference(dt);
  }

  // ----------------------------------------------------
  // Agent Start/Stop
  // ----------------------------------------------------
  void startAgent() {
    if (_isRunning) return;
    _isRunning = true;
    _agentLoop();
  }

  void stopAgent() {
    _isRunning = false;
  }

  // ----------------------------------------------------
  // MAIN LOOP (robust, null-safe)
  // ----------------------------------------------------
  Future<void> _agentLoop() async {
    while (_isRunning) {
      final now = DateTime.now();

      // Ruhezeiten-Handling
      final untilActive = _timeUntilActive(now);
      if (untilActive > Duration.zero) {
        print('Agent in Ruhezeit bis ${now.add(untilActive)}. Schlafe ${untilActive.inMinutes} Minuten.');
        await Future.delayed(untilActive);
        if (!_isRunning) break;
        continue;
      }

      // Skills nacheinander ausführen
      await _checkMedicationsSkill();
      await _checkAppointmentsSkill();
      await _checkNewMedicalNotesSkill();

      // Kurze Pause
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  // ----------------------------------------------------
  // SKILLS (examples, null-safe)
  // ----------------------------------------------------

  // MEDIKAMENTE: warne wenn wenig vorrätig
  Future<void> _checkMedicationsSkill() async {
    if (patient.medications.isEmpty) return;
    for (final med in patient.medications) {
      final int amtLeft = (med.amountLeft != null)
          ? (med.amountLeft is int ? med.amountLeft as int : int.tryParse(med.amountLeft.toString()) ?? 0)
          : 0;
      if (amtLeft < 3) {
        final name = med.name ?? 'Medikation';
        final msg = 'Achtung: $name ist fast aufgebraucht. Noch $amtLeft Stück vorhanden.';
        await _speakIfActive(msg);
      }
    }
  }

  // TERMINE + VORHERSAGE (robust)
  Future<void> _checkAppointmentsSkill() async {
    final now = DateTime.now();
    final inTwoWeeks = now.add(const Duration(days: 14));

    // Filtere nur Termine mit Datum
    final upcoming = patient.appointments.where((a) => a.date != null && a.date!.isBefore(inTwoWeeks)).toList();
    if (upcoming.isEmpty) return;

    // Gruppiere Termine nach Typ, berechne mögliche Vorhersage (vereinfachte Logik)
    final Map<String, List<DateTime>> typeToDates = {};
    for (final app in patient.appointments) {
      if (app.date == null) continue;
      typeToDates.putIfAbsent(app.type ?? 'unknown', () => []).add(app.date!);
    }

    // Beispiel: für jeden Typ nächsten Termin schätzen
    for (final entry in typeToDates.entries) {
      final dates = entry.value..sort();
      if (dates.length < 2) continue;
      // einfache durchschnittliche Intervall-Berechnung
      int totalDays = 0;
      for (int i = 1; i < dates.length; i++) {
        totalDays += dates[i].difference(dates[i - 1]).inDays;
      }
      final avg = (totalDays / (dates.length - 1)).round();
      final predicted = dates.last.add(Duration(days: avg));
      if (predicted.isBefore(inTwoWeeks)) {
        await _speakIfActive('Ein ${entry.key} Termin könnte bald fällig sein am ${predicted.toLocal().toString().split(' ')[0]}');
      }
    }
  }

  // PROTOKOLL-AUSWERTUNG (OCR/gespeicherte Notizen prüfen)
  Future<void> _checkNewMedicalNotesSkill() async {
    final now = DateTime.now();
    for (final medNote in patient.medicalNotes) {
      // Wenn Model ein status-Feld hat: defensive Prüfung
      final status = (medNote is mednote.MedicalNote) ? (medNote.status) : null;
      if (status == null || status != mednote.MedicalNoteStatus.newNote) continue;

      final text = (medNote.content ?? '').toString();
      // defensive contains-Prüfung
      if (text.contains('Folgetermin')) {
        await _speakIfActive('In einer neuen Notiz wurde ein Folgetermin erwähnt.');
      }
      if (text.contains('Aspirin')) {
        await _speakIfActive('In einer neuen Notiz wurde Aspirin erwähnt.');
      }
    }
  }

  // Einfacher TTS-Helper, der Ruhezeiten respektiert
  Future<void> _speakIfActive(String message) async {
    if (_isWithinQuietHours(DateTime.now())) {
      print('TTS unterdrückt wegen Ruhezeit: $message');
      return;
    }
    await _flutterTts.speak(message);
    // optional: warte kurz
    await Future.delayed(const Duration(seconds: 1));
  }
}
