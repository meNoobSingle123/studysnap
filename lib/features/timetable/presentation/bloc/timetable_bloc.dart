import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/timetable_slot.dart';
import '../../domain/usecases/get_subjects_usecase.dart';
import '../../domain/usecases/get_timetable_slots_usecase.dart';

// EVENTS
sealed class TimetableEvent extends Equatable {
  const TimetableEvent();

  @override
  List<Object?> get props => [];
}

class InitTimetableSubscription extends TimetableEvent {
  const InitTimetableSubscription();
}

class DaySelectedEvent extends TimetableEvent {
  final DateTime selectedDay;
  const DaySelectedEvent(this.selectedDay);

  @override
  List<Object?> get props => [selectedDay];
}

class ToggleSlotReminderEvent extends TimetableEvent {
  final String slotId;
  const ToggleSlotReminderEvent(this.slotId);

  @override
  List<Object?> get props => [slotId];
}

class _SlotsUpdatedEvent extends TimetableEvent {
  final List<TimetableSlot> slots;
  const _SlotsUpdatedEvent(this.slots);

  @override
  List<Object?> get props => [slots];
}

class _SubjectsUpdatedEvent extends TimetableEvent {
  final List<Subject> subjects;
  const _SubjectsUpdatedEvent(this.subjects);

  @override
  List<Object?> get props => [subjects];
}

// STATES
sealed class TimetableState extends Equatable {
  const TimetableState();

  @override
  List<Object?> get props => [];
}

class TimetableInitial extends TimetableState {
  const TimetableInitial();
}

class TimetableLoading extends TimetableState {
  const TimetableLoading();
}

class TimetableLoaded extends TimetableState {
  final DateTime selectedDay;
  final List<TimetableSlot> allSlots;
  final List<TimetableSlot> daySlots;
  final Map<String, Subject> subjectsMap;
  final Map<String, bool> slotReminders;
  final TimetableSlot? nextUpcomingSlot;
  final int? minutesUntilNextSlot;

  const TimetableLoaded({
    required this.selectedDay,
    required this.allSlots,
    required this.daySlots,
    required this.subjectsMap,
    this.slotReminders = const {},
    this.nextUpcomingSlot,
    this.minutesUntilNextSlot,
  });

  TimetableLoaded copyWith({
    DateTime? selectedDay,
    List<TimetableSlot>? allSlots,
    List<TimetableSlot>? daySlots,
    Map<String, Subject>? subjectsMap,
    Map<String, bool>? slotReminders,
    TimetableSlot? nextUpcomingSlot,
    int? minutesUntilNextSlot,
  }) {
    return TimetableLoaded(
      selectedDay: selectedDay ?? this.selectedDay,
      allSlots: allSlots ?? this.allSlots,
      daySlots: daySlots ?? this.daySlots,
      subjectsMap: subjectsMap ?? this.subjectsMap,
      slotReminders: slotReminders ?? this.slotReminders,
      nextUpcomingSlot: nextUpcomingSlot ?? this.nextUpcomingSlot,
      minutesUntilNextSlot: minutesUntilNextSlot ?? this.minutesUntilNextSlot,
    );
  }

  @override
  List<Object?> get props => [
        selectedDay,
        allSlots,
        daySlots,
        subjectsMap,
        slotReminders,
        nextUpcomingSlot,
        minutesUntilNextSlot,
      ];
}

class TimetableError extends TimetableState {
  final String message;
  const TimetableError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLOC
class TimetableBloc extends Bloc<TimetableEvent, TimetableState> {
  final GetTimetableSlotsUseCase slotsUseCase;
  final GetSubjectsUseCase subjectsUseCase;

  StreamSubscription<List<TimetableSlot>>? _slotsSub;
  StreamSubscription<List<Subject>>? _subjectsSub;

  List<TimetableSlot> _cachedSlots = [];
  Map<String, Subject> _cachedSubjects = {};
  DateTime _currentSelectedDay = DateTime.now();
  final Map<String, bool> _remindersMap = {};

  TimetableBloc({
    required this.slotsUseCase,
    required this.subjectsUseCase,
  }) : super(const TimetableInitial()) {
    on<InitTimetableSubscription>(_onInitSubscription);
    on<DaySelectedEvent>(_onDaySelected);
    on<ToggleSlotReminderEvent>(_onToggleReminder);
    on<_SlotsUpdatedEvent>(_onSlotsUpdated);
    on<_SubjectsUpdatedEvent>(_onSubjectsUpdated);
  }

  Future<void> _onInitSubscription(
    InitTimetableSubscription event,
    Emitter<TimetableState> emit,
  ) async {
    emit(const TimetableLoading());

    // 1. Lắng nghe Subjects từ Hive stream
    await _subjectsSub?.cancel();
    _subjectsSub = subjectsUseCase.watchSubjects().listen((subjects) {
      add(_SubjectsUpdatedEvent(subjects));
    });

    // 2. Lắng nghe Slots từ Hive stream
    await _slotsSub?.cancel();
    _slotsSub = slotsUseCase.watchAllSlots().listen((slots) {
      add(_SlotsUpdatedEvent(slots));
    });
  }

  void _onSubjectsUpdated(
    _SubjectsUpdatedEvent event,
    Emitter<TimetableState> emit,
  ) {
    _cachedSubjects = {for (final s in event.subjects) s.id: s};
    emit(_createLoadedState());
  }

  void _onSlotsUpdated(
    _SlotsUpdatedEvent event,
    Emitter<TimetableState> emit,
  ) {
    _cachedSlots = event.slots;
    emit(_createLoadedState());
  }

  void _onDaySelected(DaySelectedEvent event, Emitter<TimetableState> emit) {
    _currentSelectedDay = event.selectedDay;
    emit(_createLoadedState());
  }

  void _onToggleReminder(
    ToggleSlotReminderEvent event,
    Emitter<TimetableState> emit,
  ) {
    final current = _remindersMap[event.slotId] ?? true;
    _remindersMap[event.slotId] = !current;
    emit(_createLoadedState());
  }

  TimetableLoaded _createLoadedState() {
    final weekday = _currentSelectedDay.weekday; // 1=T2 .. 7=CN
    final daySlots = _cachedSlots
        .where((s) => s.dayOfWeek == weekday && !s.isDeleted)
        .toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    // Tính ca học tiếp theo trong ngày
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    TimetableSlot? nextSlot;
    int? minutesDiff;

    if (_isToday(_currentSelectedDay)) {
      for (final slot in daySlots) {
        if (slot.startMin > currentMinutes) {
          nextSlot = slot;
          minutesDiff = slot.startMin - currentMinutes;
          break;
        }
      }
    }

    return TimetableLoaded(
      selectedDay: _currentSelectedDay,
      allSlots: _cachedSlots,
      daySlots: daySlots,
      subjectsMap: _cachedSubjects,
      slotReminders: Map.from(_remindersMap),
      nextUpcomingSlot: nextSlot,
      minutesUntilNextSlot: minutesDiff,
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Future<void> close() {
    _slotsSub?.cancel();
    _subjectsSub?.cancel();
    return super.close();
  }
}
