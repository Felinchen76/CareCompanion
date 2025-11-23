import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart' as task_model;
import '../models/medication.dart';
import '../models/appointment.dart' as app_model;
import '../models/medical_note.dart' as mednote;
import '../models/patient.dart';
import '../models/user.dart';

class AgentService {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  AgentService._internal() : quietFromHour = 22, quietToHour = 7;
  static final AgentService instance = AgentService._internal();
  factory AgentService() => instance;

  bool _isRunning = false;

  // Ruhezeiten
  int quietFromHour;
  int quietToHour;

  // Datenmodelle
  late UserProfile user;
  late PatientProfile patient;

  bool get isRunning => _isRunning;

  Future<void> _speakIfActive(String message) async {
    final now = DateTime.now();
    if (_isWithinQuietHours(now)) {
      // unterdrücke TTS in Ruhezeiten
      // ignore: avoid_print
      print('TTS unterdrückt (Ruhezeit): $message');
      return;
    }
    try {
      await _flutterTts.speak(message);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      // ignore: avoid_print
      print('TTS error: $e');
    }
  }

  /// Erzeugt aus strukturierter Analyse eine Liste von Tasks (keine UI‑Persistenz hier).
  Future<List<task_model.Task>> applyAnalysisToPatient(Map<String, dynamic> analysis, {String? sourceTitle}) async {
    final created = <task_model.Task>[];
    final now = DateTime.now();

    // actions -> direkte Aufgaben
    final actions = (analysis['actions'] is List) ? List<Map<String, dynamic>>.from(analysis['actions']) : <Map<String, dynamic>>[];
    for (final a in actions) {
      final title = (a['title'] ?? 'Vorschlag').toString();
      DateTime date = now;
      if (a['date'] != null) {
        final parsed = DateTime.tryParse(a['date'].toString());
        if (parsed != null) date = parsed;
      }
      final t = task_model.Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title + (sourceTitle != null ? ' — aus $sourceTitle' : ''),
        date: date,
        done: false,
      );
      created.add(t);
      await _speakIfActive('Vorschlag: $title');
    }

    // medications -> eine zusammenfassende Aufgabe
    final meds = (analysis['medications'] is List) ? List<dynamic>.from(analysis['medications']) : <dynamic>[];
    if (meds.isNotEmpty) {
      final medsStr = meds.map((m) {
        if (m is Map) {
          final n = m['name'] ?? m['drug'] ?? m.toString();
          final d = m['dose'] ?? '';
          return d.toString().isNotEmpty ? '$n ($d)' : '$n';
        }
        return m.toString();
      }).join(', ');
      final t = task_model.Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Medikament prüfen / Rezept: $medsStr',
        date: now,
        done: false,
      );
      created.add(t);
      await _speakIfActive('Medikamente erkannt: $medsStr');
    }

    // dates -> konkrete Terminprüfungen
    final dates = (analysis['dates'] is List) ? List<dynamic>.from(analysis['dates']) : <dynamic>[];
    for (final d in dates) {
      DateTime? dt;
      if (d is String) dt = DateTime.tryParse(d);
      if (d is int) dt = DateTime.fromMillisecondsSinceEpoch(d);
      if (dt == null) continue;
      final t = task_model.Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Folgetermin prüfen',
        date: dt,
        done: false,
      );
      created.add(t);
      await _speakIfActive('Vorgeschlagener Termin: ${dt.toLocal().toString().split(" ")[0]}');
    }

    // debug log:
    // ignore: avoid_print
    print('[AgentService] applyAnalysisToPatient created ${created.length} tasks for source="$sourceTitle"');
    return created;
  }

  /// Simuliert Ausführung eines Tasks (z.B. Kalender öffnen / Rezept anfordern).
  /// Gibt ein kurzes Ergebnis-String zurück.
  Future<String> executeTask(task_model.Task t) async {
    final title = t.title.toLowerCase();
    // einfache heuristische Simulation
    if (title.contains('termin')) {
      // Simuliere Kalender-Action
      await _speakIfActive('Öffne Kalender, Termin anfragen.');
      return 'Simuliert: Kalender geöffnet / Terminanforderung vorbereitet für ${t.date.toLocal().toString().split(" ")[0]}.';
    }
    if (title.contains('medik') || title.contains('rezept')) {
      await _speakIfActive('Rezept-Anforderung vorbereitet.');
      return 'Simuliert: Rezeptanforderung für "${t.title}" vorbereitet.';
    }
    // Default
    await _speakIfActive('Aufgabe ausgeführt.');
    return 'Simuliert: Aufgabe "${t.title}" ausgeführt.';
  }

  // ----------------------------------------------------
  // LOAD DATA (Dummy)
  // ----------------------------------------------------
  Future<void> loadDummyData() async {
    final String jsonStr = await rootBundle.loadString('assets/data/dummy_data.json');
    final Map<String, dynamic> jsonData = json.decode(jsonStr);

    user = UserProfile.fromJson(jsonData['userProfile'] ?? <String, dynamic>{});
    patient = PatientProfile.fromJson(jsonData['patientProfile'] ?? <String, dynamic>{});
    
    // Demo: füge wiederkehrende Termine hinzu (für Recurrence-Analyse-Demo)
    final now = DateTime.now();
    try {
      final appointments = patient.appointments as List;
      if (appointments.length < 3) {
        // 3 Zahnarzt-Termine alle 180 Tage (letzter vor 10 Tagen)
        final demoApps = <app_model.Appointment>[
          app_model.Appointment.fromJson({
            'id': 'demo_app_1',
            'date': now.subtract(const Duration(days: 370)).toIso8601String(),
            'type': 'Zahnarzt',
            'doctor': 'Dr. Müller',
          }),
          app_model.Appointment.fromJson({
            'id': 'demo_app_2',
            'date': now.subtract(const Duration(days: 190)).toIso8601String(),
            'type': 'Zahnarzt',
            'doctor': 'Dr. Müller',
          }),
          app_model.Appointment.fromJson({
            'id': 'demo_app_3',
            'date': now.subtract(const Duration(days: 10)).toIso8601String(),
            'type': 'Zahnarzt',
            'doctor': 'Dr. Müller',
          }),
        ];
        for (final a in demoApps) {
          appointments.add(a);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Demo appointments error: $e');
    }
    
    // Demo: füge proaktiv einen Task hinzu (zeigt, dass Agent ohne User-Input arbeitet)
    final demoTask = task_model.Task(
      id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Proaktiv: Medikamentenbestand prüfen',
      date: DateTime.now().add(const Duration(days: 1)),
      done: false,
    );
    try {
      (patient.tasks as List).insert(0, demoTask);
    } catch (_) {}
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
    _speakIfActive('Agent gestartet. Ich überwache Medikamente, Termine und Dokumente.');
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

      // neue: tiefergehende Analyse und automatische Folgeaktionen (prototypisch)
      try {
        if (medNote is mednote.MedicalNote) {
          await _analyzeAndActOnNote(medNote);
        }
      } catch (e) {
        // ignoriere analysis errors
        // ignoriere avoid_print
        print('Note analysis failed: $e');
      }
    }
  }

  /// Analysiert eine MedicalNote, erstellt Tasks via applyAnalysisToPatient und fügt diese in patient.tasks ein.
  /// Markiert die Note als verarbeitet (falls möglich).
  Future<void> _analyzeAndActOnNote(mednote.MedicalNote note) async {
    final text = (note.content ?? '').toString();
    if (text.trim().isEmpty) return;
    // Versuche, strukturierte Analyse durchzuführen (hier: falls note.analysis bereits vorhanden, nutze sie;
    // ansonsten könnte man die Server-Analyse erneut anstoßen — für Prototype verwenden wir lokale Extraction)
    Map<String, dynamic> analysis = {};
    try {
      // Wenn note enthält bereits eine strukturierte Analyse-Felder, nutze diese
      if (note.toJson().containsKey('analysis')) {
        final a = note.toJson()['analysis'];
        if (a is Map<String, dynamic>) analysis = a;
      }
    } catch (_) {}

    // Wenn keine Analyse vorhanden: einfache heuristische Extraktion mit internen Extractors
    if (analysis.isEmpty) {
      analysis = {
        'dates': _extractDatesFromText(text).map((d) => d.toIso8601String()).toList(),
        'medications': _extractMedicationsFromText(text),
        'actions': _extractFollowUpKeywords(text).map((k) => {'title': k, 'description': 'Erkannter Hinweis: $k'}).toList(),
      };
    }

    // Erzeuge Tasks (rein lokal) und füge sie in patient.tasks ein
    final tasks = await applyAnalysisToPatient(analysis, sourceTitle: note.title);
    for (final t in tasks) {
      try {
        (patient.tasks as List).insert(0, t);
      } catch (_) {
        // ignore insertion errors
      }
    }

    // Markiere Note als verarbeitet, falls Methode/Enum vorhanden
    try {
      note.markDiscussed();
    } catch (_) {
      // falls nicht vorhanden, setze status falls Feld existiert
      try {
        note.status = mednote.MedicalNoteStatus.discussed;
      } catch (_) {}
    }
  }

  // ------------------------ NOTE ANALYSIS & ACTIONS (prototype) ------------------------
  // Duplicate analysis method removed. Use the single _analyzeAndActOnNote earlier
  // which already uses task_model.Task and _speakIfActive.

  List<DateTime> _extractDatesFromText(String text) {
    final List<DateTime> res = [];

    // 1) dd.mm.yyyy oder d.m.yyyy
    final reDe = RegExp(r'\b(\d{1,2}\.\d{1,2}\.\d{2,4})\b');
    for (final m in reDe.allMatches(text)) {
      final s = m.group(1);
      if (s != null) {
        final parts = s.split('.');
        if (parts.length >= 3) {
          final d = int.tryParse(parts[0]);
          final mo = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (d != null && mo != null && y != null) {
            try {
              final dt = DateTime(y < 100 ? 2000 + y : y, mo, d);
              res.add(dt);
            } catch (_) {}
          }
        }
      }
    }

    // 2) ISO yyyy-mm-dd
    final reIso = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b');
    for (final m in reIso.allMatches(text)) {
      final s = m.group(1);
      if (s != null) {
        final dt = DateTime.tryParse(s);
        if (dt != null) res.add(dt);
      }
    }

    // 3) relative Angaben "in X Tagen/Wochen/Monaten"
    final reRel = RegExp(r'in\s+(\d{1,3})\s+(tag|tage|tagen|woche|wochen|monat|monaten)', caseSensitive: false);
    for (final m in reRel.allMatches(text)) {
      final num = int.tryParse(m.group(1) ?? '');
      final unit = (m.group(2) ?? '').toLowerCase();
      if (num != null) {
        DateTime dt = DateTime.now();
        if (unit.startsWith('tag')) dt = dt.add(Duration(days: num));
        else if (unit.startsWith('woche')) dt = dt.add(Duration(days: num * 7));
        else if (unit.startsWith('monat')) dt = DateTime(dt.year, dt.month + num, dt.day);
        res.add(dt);
      }
    }

    // dedup & return
    final uniq = <int, DateTime>{};
    for (final d in res) uniq[d.millisecondsSinceEpoch] = d;
    return uniq.values.toList();
  }

  List<String> _extractMedicationsFromText(String text) {
    final found = <String>{};

    // einfache Liste bekannter Wirkstoffe (erweitern)
    final known = ['aspirin', 'metformin', 'lisinopril', 'ibuprofen', 'paracetamol', 'atorvastatin'];
    for (final k in known) {
      if (text.toLowerCase().contains(k)) found.add(k[0].toUpperCase() + k.substring(1));
    }

    // suche nach Mustern wie "500 mg"
    final doseRe = RegExp(r'([A-Za-zÄÖÜäöüß]{3,}\s*\d{1,4}\s?mg)', caseSensitive: false);
    for (final m in doseRe.allMatches(text)) {
      final s = m.group(1);
      if (s != null) found.add(s.trim());
    }

    return found.toList();
  }

  List<String> _extractFollowUpKeywords(String text) {
    final kws = <String>[];
    final candidates = ['Folgetermin', 'Kontrolle', 'Nachsorge', 'Überweisung', 'Rezept', 'Labor'];
    final low = text.toLowerCase();
    for (final k in candidates) {
      if (low.contains(k.toLowerCase())) kws.add(k);
    }
    return kws;
  }

}

// create a global alias for imports that want a top-level instance
final AgentService agentService = AgentService();
