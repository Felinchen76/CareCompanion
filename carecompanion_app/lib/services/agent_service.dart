import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart' show rootBundle;

class AgentService {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isRunning = false;

  // Ruhezeiten
  int quietFromHour;
  int quietToHour;

  // Daten
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> medications = [];
  List<Map<String, dynamic>> appointments = [];

  AgentService({this.quietFromHour = 22, this.quietToHour = 7});

  Future<void> loadDummyData() async {
    // JSON-Datei laden
    final String jsonStr = await rootBundle.loadString('../assets/data/dummy_data.json');
    final Map<String, dynamic> jsonData = json.decode(jsonStr);

    // Patientendaten extrahieren
    final patient = jsonData['patientProfile'];

    // Listen für Dashboard füllen
    tasks = List<Map<String, dynamic>>.from(patient['tasks']);
    medications = List<Map<String, dynamic>>.from(patient['medications']);
    appointments = List<Map<String, dynamic>>.from(patient['appointments']);
  }

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
      end = dt.hour >= quietFromHour
          ? DateTime(dt.year, dt.month, dt.day + 1, quietToHour)
          : DateTime(dt.year, dt.month, dt.day, quietToHour);
    }
    return end.difference(dt);
  }

  void startAgent() {
    _isRunning = true;
    _checkAppointments();
  }

  void stopAgent() {
    _isRunning = false;
  }

  Future<void> _checkAppointments() async {
    while (_isRunning) {
      final now = DateTime.now();
      final untilActive = _timeUntilActive(now);
      if (untilActive > Duration.zero) {
        print('Agent in Ruhezeit bis ${now.add(untilActive)}');
        await Future.delayed(untilActive);
        if (!_isRunning) break;
        continue;
      }

      // Hier kann ML/Terminerinnerungslogik implementiert werden
      // Für PoC: einfach alle Termine der nächsten 2 Wochen prüfen
      final upcoming = appointments
          .where((a) => DateTime.parse(a['date']).isBefore(now.add(Duration(days: 14))))
          .toList();

      for (var app in upcoming) {
        if (_isWithinQuietHours(DateTime.now())) break;
        String message =
            "Ein ${app['type']} Termin ist bald fällig am ${app['date']}. Willst du einen Termin dafür eintragen?";
        await _flutterTts.speak(message);
        await Future.delayed(Duration(seconds: 5));
      }

      await Future.delayed(Duration(seconds: 10));
    }
  }
}
