import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../services/backend_api.dart';
import '../services/medical_note_service.dart';
import '../models/medical_note.dart';

class ProtocolRecord {
  final String id;
  final String title;
  final String type; // 'file' | 'stt' | 'text'
  final String? path; // 'memory:filename' or actual path on mobile
  final List<int>? bytes; // raw bytes for preview/download on web/mobile
  final String? text; // erkannter Text / Notiz
  final DateTime createdAt;

  ProtocolRecord({
    required this.id,
    required this.title,
    required this.type,
    this.path,
    this.bytes,
    this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ProtocollsScreen extends StatefulWidget {
  const ProtocollsScreen({super.key});

  @override
  State<ProtocollsScreen> createState() => _ProtocollsScreenState();
}

class _ProtocollsScreenState extends State<ProtocollsScreen> {
  final List<ProtocolRecord> _records = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastRecognized = '';
  final Uuid _uuid = const Uuid();

  // optional persistent service (may fail on web)
  final MedicalNoteService _noteService = MedicalNoteService();
  final BackendApi _backend = BackendApi(baseUri: Uri.parse('http://localhost:5000'));

  @override
  void initState() {
    super.initState();
    _initServiceSafe();
  }

  Future<void> _initServiceSafe() async {
    try {
      await _noteService.init();
      final notes = _noteService.notes;
      setState(() {
        for (final n in notes) {
          _records.add(ProtocolRecord(
            id: n.id,
            title: n.title,
            type: 'text',
            path: n.sourcePath,
            text: n.content,
            createdAt: n.date,
          ));
        }
        _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    } catch (e) {
      // ignore: avoid_print
      print('MedicalNoteService.init() failed: $e');
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  // ---------------- pick & add file (web & mobile safe) ----------------
  Future<void> _pickAndAddFile() async {
    try {
      // pick file with bytes (works on web)
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pf = result.files.first;
      final bytes = pf.bytes;
      final title = pf.name;
      final displayPath = bytes == null ? pf.path : 'memory:$title';

      final rec = ProtocolRecord(
        id: _uuid.v4(),
        title: title,
        type: 'file',
        path: displayPath,
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() => _records.insert(0, rec));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Datei hinzugefügt: $title')));

      if (bytes == null) {
        // Some platforms may not provide bytes — inform user
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datei enthält keine Daten (Web)')));
        return;
      }

      // send to backend for extraction/analysis
      try {
        final resp = await _backend.analyzeFile(Uint8List.fromList(bytes), title);
        final analysis = resp['analysis'];
        // show JSON analysis to user
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Analyse Ergebnis'),
              content: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(analysis))),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }

        // persist note (best-effort)
        try {
          final noteJson = {
            'id': rec.id,
            'title': rec.title,
            'content': analysis is Map && analysis['raw'] != null ? analysis['raw'] : '',
            'date': rec.createdAt.toIso8601String(),
            'type': 'file',
            'sourcePath': rec.path,
            'status': MedicalNoteStatus.newNote.index,
          };
          final note = MedicalNote.fromJson(noteJson);
          await _noteService.addNote(note);
        } catch (e) {
          // ignore persistence errors on some platforms
          // ignore: avoid_print
          print('Persisting note failed: $e');
        }

        // optional: display suggested actions as records
        final actions = (analysis is Map && analysis['actions'] is List) ? (analysis['actions'] as List) : [];
        for (final a in actions) {
          final titleA = (a['title'] ?? 'Vorschlag').toString();
          final desc = (a['description'] ?? '').toString();
          DateTime? dt;
          if (a['date'] != null) dt = DateTime.tryParse(a['date'].toString());
          if (!mounted) continue;
          setState(() {
            _records.insert(
              0,
              ProtocolRecord(
                id: _uuid.v4(),
                title: 'Action: $titleA',
                type: 'text',
                text: desc,
                createdAt: dt,
              ),
            );
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analyse fehlgeschlagen: $e')));
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[_pickAndAddFile] ERROR: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Hinzufügen: $e')));
    }
  }

  // ---------------- recording (STT) ----------------
  Future<void> _toggleRecording() async {
    if (!_isListening) {
      final available = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (e) {
          setState(() => _isListening = false);
        },
      );
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spracherkennung nicht verfügbar')));
        return;
      }
      setState(() {
        _isListening = true;
        _lastRecognized = '';
      });
      _speech.listen(onResult: (result) {
        setState(() {
          _lastRecognized = result.recognizedWords;
        });
      });
    } else {
      await _speech.stop();
      setState(() => _isListening = false);

      final text = _lastRecognized.trim();
      if (text.isEmpty) return;

      final rec = ProtocolRecord(
        id: _uuid.v4(),
        title: 'Gesprochenes Protokoll (${DateTime.now().toLocal().toString().split(' ')[0]})',
        type: 'stt',
        text: text,
      );

      if (!mounted) return;
      setState(() => _records.insert(0, rec));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gesprochenes Protokoll gespeichert')));

      // persist best-effort
      try {
        final noteJson = {
          'id': rec.id,
          'title': rec.title,
          'content': rec.text,
          'date': rec.createdAt.toIso8601String(),
          'type': 'stt',
          'status': MedicalNoteStatus.newNote.index,
        };
        final note = MedicalNote.fromJson(noteJson);
        await _noteService.addNote(note);
      } catch (e) {
        // ignore persistence errors
        // ignore: avoid_print
        print('Persisting STT note failed: $e');
      }

      _lastRecognized = '';
    }
  }

  // ---------------- manual text ----------------
  Future<void> _addManualText() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Neues Protokoll (Text)'),
        content: TextField(controller: ctrl, maxLines: 6, decoration: const InputDecoration(hintText: 'Text hier eingeben...')),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(ctrl.text), child: const Text('Speichern')),
        ],
      ),
    );
    if (res == null || res.trim().isEmpty) return;

    final rec = ProtocolRecord(
      id: _uuid.v4(),
      title: 'Manuelles Protokoll (${DateTime.now().toLocal().toString().split(' ')[0]})',
      type: 'text',
      text: res.trim(),
    );

    if (!mounted) return;
    setState(() => _records.insert(0, rec));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Protokoll gespeichert')));

    // persist best-effort
    try {
      final noteJson = {
        'id': rec.id,
        'title': rec.title,
        'content': rec.text,
        'date': rec.createdAt.toIso8601String(),
        'type': 'text',
        'status': MedicalNoteStatus.newNote.index,
      };
      final note = MedicalNote.fromJson(noteJson);
      await _noteService.addNote(note);
    } catch (e) {
      // ignore
      // ignore: avoid_print
      print('Persisting manual note failed: $e');
    }
  }

  void _showRecordDetail(ProtocolRecord r) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Typ: ${r.type}'),
            const SizedBox(height: 8),
            Text('Erstellt: ${r.createdAt.toLocal()}'),
            const SizedBox(height: 12),
            if (r.path != null) Text('Quelle: ${r.path}'),
            if (r.text != null) ...[
              const SizedBox(height: 12),
              const Text('Inhalt:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(r.text!),
            ],
            if (r.bytes != null) ...[
              const SizedBox(height: 12),
              const Text('Datei vorhanden (Bytes)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Schließen'))),
          ]),
        ),
      ),
    );
  }

  Widget _buildListTile(ProtocolRecord r) {
    IconData icon;
    String subtitle;
    if (r.type == 'file') {
      icon = Icons.insert_drive_file;
      subtitle = r.path ?? (r.bytes != null ? '(in-memory file)' : '');
    } else if (r.type == 'stt') {
      icon = Icons.mic;
      subtitle = (r.text ?? '').split('\n').first;
    } else {
      icon = Icons.note;
      subtitle = (r.text ?? '').split('\n').first;
    }
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(r.title),
        subtitle: Text(subtitle),
        trailing: Text('${r.createdAt.toLocal().toString().split(' ')[0]}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        onTap: () => _showRecordDetail(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protokolle'),
        actions: [
          IconButton(tooltip: 'Upload Datei', icon: const Icon(Icons.upload_file), onPressed: _pickAndAddFile),
          IconButton(tooltip: 'Neues Protokoll (Text)', icon: const Icon(Icons.note_add), onPressed: _addManualText),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                label: Text(_isListening ? 'Stop Recording' : 'Record Protokoll'),
                onPressed: _toggleRecording,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(icon: const Icon(Icons.upload_file), label: const Text('Upload'), onPressed: _pickAndAddFile),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: _records.isEmpty ? const Center(child: Text('Keine Protokolle vorhanden.')) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _records.length, itemBuilder: (c, i) => _buildListTile(_records[i])),
        ),
      ]),
    );
  }
}