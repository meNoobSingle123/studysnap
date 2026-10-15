import '../../domain/entities/campus_building.dart';
import '../../domain/entities/exam_schedule.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/repositories/timetable_repository.dart';
import '../datasources/timetable_local_datasource.dart';
import '../models/building_model.dart';
import '../models/exam_model.dart';
import '../models/slot_model.dart';
import '../models/subject_model.dart';

class TimetableRepositoryImpl implements TimetableRepository {
  final TimetableLocalDataSource localDataSource;

  TimetableRepositoryImpl({required this.localDataSource});

  @override
  Stream<List<TimetableSlot>> watchSlotsByDay(int dayOfWeek) {
    return localDataSource.watchSlotsByDay(dayOfWeek);
  }

  @override
  Stream<List<TimetableSlot>> watchAllSlots() {
    return localDataSource.watchAllSlots();
  }

  @override
  Stream<List<Subject>> watchSubjects() {
    return localDataSource.watchSubjects();
  }

  @override
  Future<List<Subject>> getSubjects() {
    return localDataSource.getSubjects();
  }

  @override
  Future<Subject?> getSubjectById(String id) {
    return localDataSource.getSubjectById(id);
  }

  @override
  Future<void> saveSubject(Subject subject) {
    return localDataSource.saveSubject(SubjectModel.fromEntity(subject));
  }

  @override
  Future<void> softDeleteSubject(String id) {
    return localDataSource.softDeleteSubject(id);
  }

  @override
  Future<void> saveSlots(List<TimetableSlot> slots) {
    final models = slots.map((s) => TimetableSlotModel.fromEntity(s)).toList();
    return localDataSource.saveSlots(models);
  }

  @override
  Future<TimetableSlot?> getSlotById(String id) {
    return localDataSource.getSlotById(id);
  }

  @override
  Future<void> deleteSlot(String id) {
    return localDataSource.deleteSlot(id);
  }

  @override
  Future<List<ExamSchedule>> getExams() {
    return localDataSource.getExams();
  }

  @override
  Future<void> saveExams(List<ExamSchedule> exams) {
    final models = exams.map((e) => ExamScheduleModel.fromEntity(e)).toList();
    return localDataSource.saveExams(models);
  }

  @override
  Future<List<CampusBuilding>> getBuildings() {
    return localDataSource.getBuildings();
  }

  @override
  Future<void> saveBuildings(List<CampusBuilding> buildings) {
    final models = buildings.map((b) => CampusBuildingModel.fromEntity(b)).toList();
    return localDataSource.saveBuildings(models);
  }
}
