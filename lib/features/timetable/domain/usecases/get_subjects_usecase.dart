import '../entities/subject.dart';
import '../repositories/timetable_repository.dart';

class GetSubjectsUseCase {
  final TimetableRepository _repository;

  const GetSubjectsUseCase(this._repository);

  Stream<List<Subject>> watchSubjects() {
    return _repository.watchSubjects();
  }

  Future<List<Subject>> getSubjects() {
    return _repository.getSubjects();
  }

  Future<Subject?> getSubjectById(String id) {
    return _repository.getSubjectById(id);
  }
}
