import 'dart:convert';

class Medication {
  final String id;
  final String name;
  final String dose;
  final int amountLeft;
  final int refillInDays;

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.amountLeft,
    required this.refillInDays,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'],
      dose: json['dose'],
      amountLeft: json['amountLeft'],
      refillInDays: json['refillInDays'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'amountLeft': amountLeft,
        'refillInDays': refillInDays,
      };
}
