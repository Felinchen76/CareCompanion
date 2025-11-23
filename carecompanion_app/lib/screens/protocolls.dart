import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../services/backend_api.dart';
import '../services/medical_note_service.dart';
import '../services/agent_service.dart';
import '../models/task.dart' as task_model;
import '../models/medical_note.dart';

class ProtocolRecord {
  final String id;
  final String title;
  final String type; // 'file' | 'stt' | 'text'
  final String? path; // 'memory:filename' or actual path on mobile
  final List<int>? bytes; // raw bytes for preview/download on web/mobile
  final String? text; // erkannter Text / Notiz
  final Map<String, dynamic>? analysis; // strukturierte Analyse vom Backend/OpenAI
  final DateTime createdAt;

  ProtocolRecord({
    required this.id,
    required this.title,
    required this.type,
    this.path,
    this.bytes,
    this.text,
    this.analysis,
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
  final AgentService _agent = AgentService();

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
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.isEmpty) return;

      final pf = result.files.first;
      final bytes = pf.bytes;
      final title = pf.name;

      if (bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datei enthält keine Daten (Plattform-Limitation)')));
        return;
      }

      final rec = ProtocolRecord(
        id: _uuid.v4(),
        title: title,
        type: 'file',
        path: 'memory:$title',
        bytes: bytes,
      );

      if (!mounted) return;
      setState(() => _records.insert(0, rec));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Datei hinzugefügt: $title')));

      // Jetzt analysieren (rufe _analyzeFile auf)
      await _analyzeFile(rec);

    } catch (e, st) {
      // ignore: avoid_print
      print('[_pickAndAddFile] ERROR: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
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
            const SizedBox(height: 12),
            if (r.analysis != null) ...[
              const Text('Analyse (strukturierte Daten):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SizedBox(
                height: 160,
                child: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(r.analysis))),
              ),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Agent erneut ausführen'),
                  onPressed: () async {
                    Navigator.of(c).pop();
                    final created = await _agent.applyAnalysisToPatient(r.analysis!, sourceTitle: r.title);
                    if (created.isNotEmpty) {
                      for (final t in created) {
                        if (!mounted) continue;
                        setState(() {
                          _records.insert(0, ProtocolRecord(
                            id: _uuid.v4(),
                            title: 'Task: ${t.title}',
                            type: 'text',
                            text: 'Datum: ${t.date.toLocal().toString().split(" ")[0]}',
                            createdAt: t.date,
                          ));
                        });
                      }
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agent erzeugte ${created.length} Tasks')));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Tasks erzeugt')));
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // show raw analysis in bigger dialog
                    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Analyse (JSON)'), content: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(r.analysis))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
                  },
                  child: const Text('Mehr'),
                ),
              ]),
            ],
            if (r.bytes != null) ...[
              const SizedBox(height: 12),
              const Text('Datei vorhanden (Bytes)', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
            // If this record is a stored Task (text contains task JSON), allow execution
            if (r.title.startsWith('Task:') && r.text != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Aufgabe ausführen (simuliert)'),
                onPressed: () async {
                  Navigator.of(c).pop();
                  try {
                    final Map<String, dynamic> tj = jsonDecode(r.text!);
                    final task = task_model.Task.fromJson(tj);
                    final res = await _agent.executeTask(task);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ausführen fehlgeschlagen: $e')));
                  }
                },
              ),
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

  Future<void> _analyzeFile(ProtocolRecord rec) async {
    if (rec.bytes == null || rec.bytes!.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datei enthält keine Daten')));
      return;
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analysiere Dokument...')));

    try {
      // Backend-Analyse
      final url = Uri.parse('http://127.0.0.1:5000/analyze');
      final req = http.MultipartRequest('POST', url);
      req.files.add(http.MultipartFile.fromBytes('file', rec.bytes!, filename: rec.title));

      final streamedResp = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamedResp);

      if (resp.statusCode != 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backend-Fehler: ${resp.statusCode}')));
        return;
      }

      final Map<String, dynamic> data = jsonDecode(resp.body);
      if (data['success'] != true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyse fehlgeschlagen')));
        return;
      }

      final analysisData = data['analysis'] as Map<String, dynamic>? ?? <String, dynamic>{};
      
      // DEBUG: log analysisData
      // ignoriere: avoid_print
      print('[Protocolls] Backend analysis: ${const JsonEncoder.withIndent("  ").convert(analysisData)}');

      // Zeige Analyse-Ergebnis
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Analyse Ergebnis'),
            content: SingleChildScrollView(
              child: Text(const JsonEncoder.withIndent('  ').convert(analysisData)),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }

      // Speichere Note
      try {
        final noteJson = {
          'id': rec.id,
          'title': rec.title,
          'content': analysisData['raw'] ?? '',
          'date': rec.createdAt.toIso8601String(),
          'type': 'file',
          'sourcePath': rec.path,
          'status': MedicalNoteStatus.newNote.index,
          'analysis': analysisData,
        };
        final note = MedicalNote.fromJson(noteJson);
        await _noteService.addNote(note);
        // ignore: avoid_print
        print('[Protocolls] Note saved: ${note.id}');
      } catch (e) {
        // ignore: avoid_print
        print('Persisting note failed: $e');
      }

      // Baue Task-Vorschläge
      final proposed = <task_model.Task>[];

      // 1. Actions
      final actions = (analysisData['actions'] is List) ? (analysisData['actions'] as List) : [];
      // ignoriere: avoid_print
      print('[Protocolls] Found ${actions.length} actions in analysis');
      for (final a in actions) {
        final titleA = (a is Map ? (a['title'] ?? a['action'] ?? 'Vorschlag') : a).toString();
        DateTime dateA = DateTime.now().add(const Duration(days: 1));
        if (a is Map && a['date'] != null) {
          final parsed = DateTime.tryParse(a['date'].toString());
          if (parsed != null) dateA = parsed;
        }
        proposed.add(task_model.Task(
          id: _uuid.v4(),
          title: titleA,
          date: dateA,
          done: false,
        ));
      }

      // 2. Medications
      final meds = (analysisData['medications'] is List) ? List.from(analysisData['medications']) : [];
      // ignore: avoid_print
      print('[Protocolls] Found ${meds.length} medications in analysis');
      if (meds.isNotEmpty) {
        final medsStr = meds.map((m) {
          if (m is Map) {
            final n = m['name'] ?? m['drug'] ?? m.toString();
            final d = m['dose'] ?? '';
            return d.toString().isNotEmpty ? '$n ($d)' : '$n';
          }
          return m.toString();
        }).join(', ');
        proposed.add(task_model.Task(
          id: _uuid.v4(),
          title: 'Medikamente prüfen: $medsStr',
          date: DateTime.now().add(const Duration(days: 1)),
          done: false,
        ));
      }

      // 3. Dates
      final dates = (analysisData['dates'] is List) ? List.from(analysisData['dates']) : [];
      // ignore: avoid_print
      print('[Protocolls] Found ${dates.length} dates in analysis');
      for (final d in dates) {
        DateTime? dt;
        if (d is String) dt = DateTime.tryParse(d);
        if (d is int) dt = DateTime.fromMillisecondsSinceEpoch(d);
        if (dt != null) {
          proposed.add(task_model.Task(
            id: _uuid.v4(),
            title: 'Termin: ${dt.day}.${dt.month}.${dt.year}',
            date: dt.subtract(const Duration(days: 1)), // 1 Tag vorher erinnern
            done: false,
          ));
        }
      }

      // ignore: avoid_print
      print('[Protocolls] Total proposed tasks: ${proposed.length}');

      // Falls keine Proposals, zeige Info
      if (proposed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keine konkreten Aufgaben gefunden')),
          );
        }
        return;
      }

      // Zeige Dialog mit Vorschlägen
      final accept = await _showProposedTasksDialog(proposed) ?? false;
      // ignore: avoid_print
      print('[Protocolls] User accepted proposals: $accept');

      if (accept) {
        // Erstelle Tasks via Agent
        final created = await _agent.applyAnalysisToPatient(analysisData, sourceTitle: rec.title);
        // ignore: avoid_print
        print('[Protocolls] Agent created ${created.length} tasks');

        // Füge Tasks zu patient.tasks hinzu (für Dashboard)
        for (final t in created) {
          try {
            (_agent.patient.tasks as List).insert(0, t);
          } catch (e) {
            // ignore: avoid_print
            print('Failed to insert task into patient.tasks: $e');
          }
        }

        // Füge auch zu Protokollen hinzu (für lokale Anzeige)
        if (mounted) {
          setState(() {
            for (final t in created) {
              _records.insert(
                0,
                ProtocolRecord(
                  id: _uuid.v4(),
                  title: '✓ Task: ${t.title}',
                  type: 'task',
                  text: jsonEncode(t.toJson()),
                  createdAt: t.date,
                ),
              );
            }
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${created.length} Aufgaben erstellt'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vorschläge verworfen')),
          );
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Analyze error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<bool?> _showProposedTasksDialog(List<task_model.Task> proposed) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Vorgeschlagene Aufgaben'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Der Agent hat ${proposed.length} Aufgaben aus dem Dokument extrahiert:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...proposed.map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.task_alt, color: Colors.blue),
                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Fällig: ${t.date.day}.${t.date.month}.${t.date.year}'),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Verwerfen'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Aufgaben erstellen'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
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