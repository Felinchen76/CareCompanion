enum MedicalNoteStatus { newNote, discussed, ignored }

class MedicalNote {
  final String id;
  final String title;
  final String content;
  final String type; // z.B. "Arztbrief" oder "Protokoll"
  final DateTime date; // wann erstellt oder hochgeladen
  MedicalNoteStatus status;

  MedicalNote({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.date,
    this.status = MedicalNoteStatus.newNote,
  });

  factory MedicalNote.fromJson(Map<String, dynamic> json) => MedicalNote(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        type: json['type'],                       
        date: DateTime.parse(json['date']),       
        status: MedicalNoteStatus.values[json['status']],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type,                             
        'date': date.toIso8601String(),           
        'status': status.index,
      };
}
