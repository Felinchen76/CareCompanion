class Appointment {
  final String id;
  final DateTime date;
  final String type;
  final String doctor;

  Appointment({
    required this.id,
    required this.date,
    required this.type,
    this.doctor = '', // Mache doctor optional mit default value
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        type: json['type'] as String,
        doctor: json['doctor'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type,
        'doctor': doctor,
      };
}
