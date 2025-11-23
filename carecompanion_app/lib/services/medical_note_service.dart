import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medical_note.dart';

class MedicalNoteService {
  static const String _storageKey = 'medical_notes_v1';

  List<MedicalNote> notes = [];

  MedicalNoteService();

  /// Initialisiert den Service (lade bestehende Notizen)
  Future<void> init() async {
    await loadNotes();
  }

  /// Lade Notizen aus SharedPreferences (plattformübergreifend, inkl. Web)
  Future<void> loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        notes = [];
        await saveNotes(); // lege leere Datei an
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        notes = decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => MedicalNote.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else {
        notes = [];
      }
    } catch (e) {
      // fallback: leere Liste bei Fehler
      // ignore: avoid_print
      print('MedicalNoteService.loadNotes error: $e');
      notes = [];
    }
  }

  /// Speichere alle Notizen persistent
  Future<void> saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = notes.map((n) => n.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      // ignore: avoid_print
      print('MedicalNoteService.saveNotes error: $e');
    }
  }

  /// Neues Dokument / Upload hinzufügen und persistieren
  Future<void> addNote(MedicalNote note) async {
    notes.insert(0, note);
    await saveNotes();
  }

  /// Notiz updaten (by id)
  Future<void> updateNote(MedicalNote updated) async {
    final idx = notes.indexWhere((n) => n.id == updated.id);
    if (idx >= 0) {
      notes[idx] = updated;
      await saveNotes();
    } else {
      // falls nicht gefunden, anhängen
      await addNote(updated);
    }
  }

  /// Notiz löschen (by id)
  Future<void> removeNoteById(String id) async {
    notes.removeWhere((n) => n.id == id);
    await saveNotes();
  }
}
