// Dokumente einlesen per ocr
// muss ich ins json format umwandeln und dann in json db speichern...?
// pdfs, bilder, text


class OcrRecord {
  String id;
  String text;
  String sourcePath; // Pfad zur Bilddatei (falls vorhanden)
  DateTime createdAt;
  Map<String, dynamic>? metadata;

  OcrRecord({
    required this.id,
    required this.text,
    required this.sourcePath,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'sourcePath': sourcePath,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
      };

  static OcrRecord fromJson(Map<String, dynamic> j) => OcrRecord(
        id: j['id'] as String,
        text: j['text'] as String,
        sourcePath: j['sourcePath'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        metadata: (j['metadata'] as Map<String, dynamic>?) ?? {},
      );
}