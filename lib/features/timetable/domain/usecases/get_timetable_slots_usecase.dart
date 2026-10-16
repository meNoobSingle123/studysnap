import '../entities/timetable_slot.dart';
import '../repositories/timetable_repository.dart';

class GetTimetableSlotsUseCase {
  final TimetableRepository _repository;

  const GetTimetableSlotsUseCase(this._repository);

  Stream<List<TimetableSlot>> watchSlotsByDay(int dayOfWeek) {
    return _repository.watchSlotsByDay(dayOfWeek);
  }

  Stream<List<TimetableSlot>> watchAllSlots() {
    return _repository.watchAllSlots();
  }
}
