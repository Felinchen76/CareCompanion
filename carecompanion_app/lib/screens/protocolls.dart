import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

class ProtocolRecord {
  final String id;
  final String title;
  final String type; // 'file' | 'stt' | 'text'
  final String? path; // lokale Datei-Pfad (falls vorhanden)
  final String? text; // erkannter Text / Notiz
  final DateTime createdAt;

  ProtocolRecord({
    required this.id,
    required this.title,
    required this.type,
    this.path,
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

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _pickAndAddFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    final title = file.name;

    setState(() {
      _records.insert(
        0,
        ProtocolRecord(
          id: _uuid.v4(),
          title: title,
          type: 'file',
          path: path,
          text: null,
        ),
      );
    });
  }

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
      if (!available) return;
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
      // Save recognized text as a new record (if any)
      if (_lastRecognized.trim().isNotEmpty) {
        setState(() {
          _records.insert(
            0,
            ProtocolRecord(
              id: _uuid.v4(),
              title: 'Gesprochenes Protokoll (${DateTime.now().toLocal().toString().split(' ')[0]})',
              type: 'stt',
              path: null,
              text: _lastRecognized.trim(),
            ),
          );
          _lastRecognized = '';
        });
      }
    }
  }

  Future<void> _addManualText() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Neues Protokoll (Text)'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Text hier eingeben...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(ctrl.text), child: const Text('Speichern')),
        ],
      ),
    );
    if (res == null || res.trim().isEmpty) return;
    setState(() {
      _records.insert(
        0,
        ProtocolRecord(
          id: _uuid.v4(),
          title: 'Manuelles Protokoll (${DateTime.now().toLocal().toString().split(' ')[0]})',
          type: 'text',
          text: res.trim(),
        ),
      );
    });
  }

  void _showRecordDetail(ProtocolRecord r) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Typ: ${r.type}'),
              const SizedBox(height: 8),
              Text('Erstellt: ${r.createdAt.toLocal()}'),
              const SizedBox(height: 12),
              if (r.path != null) Text('Dateipfad: ${r.path}'),
              if (r.text != null) ...[
                const SizedBox(height: 12),
                const Text('Inhalt:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(r.text!),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(c).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(ProtocolRecord r) {
    IconData icon;
    String subtitle;
    if (r.type == 'file') {
      icon = Icons.insert_drive_file;
      subtitle = r.path ?? '';
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
        trailing: Text(
          '${r.createdAt.toLocal().toString().split(' ')[0]}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
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
          IconButton(
            tooltip: 'Upload Datei',
            icon: const Icon(Icons.upload_file),
            onPressed: _pickAndAddFile,
          ),
          IconButton(
            tooltip: 'Neues Protokoll (Text)',
            icon: const Icon(Icons.note_add),
            onPressed: _addManualText,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    label: Text(_isListening ? 'Stop Recording' : 'Record Protokoll'),
                    onPressed: _toggleRecording,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload'),
                  onPressed: _pickAndAddFile,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _records.isEmpty
                ? const Center(child: Text('Keine Protokolle vorhanden.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _records.length,
                    itemBuilder: (c, i) => _buildListTile(_records[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
