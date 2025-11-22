import '../models/medical_note.dart';
import '../models/patient.dart';

class MedicalNoteRepository {
  final PatientProfile patient;

  MedicalNoteRepository(this.patient);

  void addNote(MedicalNote note) {
    patient.medicalNotes.add(note);
  }

  List<MedicalNote> get allNotes => patient.medicalNotes;

  void removeNote(String id) {
    patient.medicalNotes.removeWhere((note) => note.id == id);
  }
}
