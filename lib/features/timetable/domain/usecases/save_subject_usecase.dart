import '../entities/subject.dart';
import '../repositories/timetable_repository.dart';

class SaveSubjectUseCase {
  final TimetableRepository _repository;

  const SaveSubjectUseCase(this._repository);

  Future<void> execute(Subject subject) {
    return _repository.saveSubject(subject);
  }

  Future<void> delete(String id) {
    return _repository.softDeleteSubject(id);
  }
}
