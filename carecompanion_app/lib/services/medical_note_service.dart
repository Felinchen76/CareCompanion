import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../models/medical_note.dart';

class MedicalNoteService {
  late File _localFile;
  List<MedicalNote> notes = [];

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _localFile = File('${dir.path}/medical_notes.json');

    if (!await _localFile.exists()) {
      // Kopiere Dummy aus Assets
      final dummy = await rootBundle.loadString('assets/data/dummy_medical_notes.json');
      await _localFile.writeAsString(dummy);
    }

    await loadNotes();
  }

  Future<void> loadNotes() async {
    final content = await _localFile.readAsString();
    final List<dynamic> jsonData = json.decode(content);
    notes = jsonData.map((e) => MedicalNote.fromJson(e)).toList();
  }

  Future<void> saveNotes() async {
    final jsonData = notes.map((e) => e.toJson()).toList();
    await _localFile.writeAsString(json.encode(jsonData));
  }

  // Neues Dokument / Upload simulieren
  Future<void> addNote(MedicalNote note) async {
    notes.add(note);
    await saveNotes();
  }
}
