// hier werden dateien und Arztprotokolle verwaltet
// Person kann Arzttermin protokollieren und später mit Agenten nachbesprechen

import 'package:flutter/material.dart';
import '../services/agent_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class DocumentsScreen extends StatefulWidget {
  final AgentService agent;
  const DocumentsScreen({super.key, required this.agent});

  @override
  _DocumentsScreenState createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  void _showAddNoteDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.mic),
            title: Text('Sprache aufnehmen'),
            onTap: () {
              Navigator.of(ctx).pop();
              _startSpeechToText();
            },
          ),
          ListTile(
            leading: Icon(Icons.upload_file),
            title: Text('Datei hochladen / Foto'),
            onTap: () {
              Navigator.of(ctx).pop();
              _startFileUpload();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startSpeechToText() async {
    bool available = await _speech.initialize();
    if (!available) return;

    _speech.listen(onResult: (result) {
      if (result.finalResult) {
        widget.agent.addMedicalNote({
          'title': 'Gesprächsprotokoll',
          'date': DateTime.now().toIso8601String(),
          'content': result.recognizedWords,
          'type': 'Gesprächsprotokoll',
        });
        setState(() {});
      }
    });
  }

  Future<void> _startFileUpload() async {
    // TODO: Implementiere Datei-Upload & OCR
    final extractedText = "Dummy Text aus OCR";
    widget.agent.addMedicalNote({
      'title': 'Arztbrief',
      'date': DateTime.now().toIso8601String(),
      'content': extractedText,
      'type': 'Arztbrief',
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.agent.medicalNotes;

    return Scaffold(
      appBar: AppBar(title: Text('Dokumente / Protokolle')),
      body: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: notes.length,
        itemBuilder: (ctx, i) {
          final note = notes[i];
          return Card(
            child: ListTile(
              title: Text(note['title']),
              subtitle: Text(note['content']),
              trailing: Text(note['date'].substring(0, 10)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}

