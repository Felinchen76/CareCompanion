import 'medical_note.dart';

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) {
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
  return null;
}

class Task {
  final String title;
  final String? description;
  final DateTime? date;

  Task({required this.title, this.description, this.date});

  factory Task.fromJson(Map<String, dynamic> j) {
    return Task(
      title: (j['title'] ?? j['name'] ?? '').toString(),
      description: j['description']?.toString(),
      date: _parseDate(j['date']),
    );
  }

  get id => null;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'date': date?.toIso8601String(),
      };

  @override
  String toString() => title;
}

class Medication {
  final String name;
  final String? dose;
  final int amountLeft; // non-nullable, default 0

  Medication({required this.name, this.dose, required this.amountLeft});

  factory Medication.fromJson(Map<String, dynamic> j) {
    final dynamic amt = j['amountLeft'];
    final int parsedAmt = (amt is int)
        ? amt
        : int.tryParse((amt ?? '').toString()) ?? 0;
    return Medication(
      name: (j['name'] ?? j['title'] ?? '').toString(),
      dose: j['dose']?.toString(),
      amountLeft: parsedAmt,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dose': dose,
        'amountLeft': amountLeft,
      };
}

class Appointment {
  final String type;
  final String? title;
  final DateTime? date;

  Appointment({required this.type, this.title, this.date});

  factory Appointment.fromJson(Map<String, dynamic> j) {
    return Appointment(
      type: (j['type'] ?? j['title'] ?? '').toString(),
      title: j['title']?.toString(),
      date: _parseDate(j['date']),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'date': date?.toIso8601String(),
      };
}

// MedicalNote wird aus models/medical_note.dart importiert – nicht hier definiert.

class PatientProfile {
  final String id;
  final String name;
  final List<Task> tasks;
  final List<Medication> medications;
  final List<Appointment> appointments;
  final List<MedicalNote> medicalNotes;

  PatientProfile({
    required this.id,
    required this.name,
    required this.tasks,
    required this.medications,
    required this.appointments,
    required this.medicalNotes,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> j) {
    final rawTasks = (j['tasks'] as List<dynamic>?) ?? [];
    final rawMeds = (j['medications'] as List<dynamic>?) ?? [];
    final rawApps = (j['appointments'] as List<dynamic>?) ?? [];
    final rawNotes = (j['medicalNotes'] as List<dynamic>?) ?? (j['documents'] as List<dynamic>?) ?? [];

    return PatientProfile(
      id: (j['id'] ?? j['patientId'] ?? '').toString(),
      name: (j['name'] ?? j['fullName'] ?? '').toString(),
      tasks: rawTasks.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      medications: rawMeds.map((e) => Medication.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      appointments: rawApps.map((e) => Appointment.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      medicalNotes: rawNotes.map((e) => MedicalNote.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'medications': medications.map((m) => m.toJson()).toList(),
        'appointments': appointments.map((a) => a.toJson()).toList(),
        'medicalNotes': medicalNotes.map((n) => n.toJson()).toList(),
      };
}