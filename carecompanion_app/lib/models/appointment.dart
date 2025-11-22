class Appointment {
  final String id;
  final String type;
  final DateTime date;

  Appointment({
    required this.id,
    required this.type,
    required this.date,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'],
        type: json['type'],
        date: DateTime.parse(json['date']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'date': date.toIso8601String(),
      };
}
