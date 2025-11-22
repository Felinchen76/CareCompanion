// ...existing code...
/// Modell für medizinische Notizen / Protokolle

enum MedicalNoteStatus { newNote, discussed, ignored }

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) {
    // Versuche ISO-String oder numeric epoch
    try {
      return DateTime.parse(v);
    } catch (_) {
      final ms = int.tryParse(v);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }
  return DateTime.now();
}

MedicalNoteStatus _parseStatus(dynamic v) {
  if (v == null) return MedicalNoteStatus.newNote;
  if (v is MedicalNoteStatus) return v;
  if (v is int) {
    if (v >= 0 && v < MedicalNoteStatus.values.length) return MedicalNoteStatus.values[v];
    return MedicalNoteStatus.newNote;
  }
  if (v is String) {
    final asInt = int.tryParse(v);
    if (asInt != null && asInt >= 0 && asInt < MedicalNoteStatus.values.length) {
      return MedicalNoteStatus.values[asInt];
    }
    final lower = v.toLowerCase();
    for (final s in MedicalNoteStatus.values) {
      if (s.toString().toLowerCase().endsWith(lower)) return s;
    }
  }
  return MedicalNoteStatus.newNote;
}

String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

class MedicalNote {
  final String id;
  final String title;
  final String content;
  final String type; // z.B. "Arztbrief", "Protokoll", "Bild"
  final DateTime date; // Erstellungs-/Hochladedatum
  MedicalNoteStatus status;
  final String? sourcePath; // optionaler Pfad/URL zur Originaldatei (lokal/cloud/memory)

  MedicalNote({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.date,
    this.status = MedicalNoteStatus.newNote,
    this.sourcePath,
  });

  /// Robust factory from JSON / Map — akzeptiert unterschiedliche Feldnamen und Typen.
  factory MedicalNote.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['noteId'] ?? '').toString();
    final title = (json['title'] ?? json['name'] ?? '').toString();
    final content = (json['content'] ?? json['text'] ?? '').toString();
    final type = (json['type'] ?? json['category'] ?? 'protokoll').toString();
    final date = _parseDate(json['date']);
    final status = _parseStatus(json['status'] ?? json['state']);
    final sourcePath = (json['sourcePath'] ?? json['source'] ?? json['path'])?.toString();

    return MedicalNote(
      id: id.isNotEmpty ? id : _generateId(),
      title: title.isNotEmpty ? title : 'Notiz ${date.toIso8601String()}',
      content: content,
      type: type,
      date: date,
      status: status,
      sourcePath: sourcePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'date': date.toIso8601String(),
      'status': status.index,
      if (sourcePath != null) 'sourcePath': sourcePath,
    };
  }

  MedicalNote copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    DateTime? date,
    MedicalNoteStatus? status,
    String? sourcePath,
  }) {
    return MedicalNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      date: date ?? this.date,
      status: status ?? this.status,
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }

  bool get isNew => status == MedicalNoteStatus.newNote;
  bool get isDiscussed => status == MedicalNoteStatus.discussed;
  bool get isIgnored => status == MedicalNoteStatus.ignored;

  void markDiscussed() => status = MedicalNoteStatus.discussed;
  void markIgnored() => status = MedicalNoteStatus.ignored;
  void markNew() => status = MedicalNoteStatus.newNote;

  @override
  String toString() {
    return 'MedicalNote(id: $id, title: $title, date: ${date.toIso8601String()}, status: $status, source: $sourcePath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MedicalNote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}