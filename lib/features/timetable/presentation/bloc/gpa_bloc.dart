import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/calculate_gpa_usecase.dart';

// EVENTS
sealed class GpaEvent extends Equatable {
  const GpaEvent();

  @override
  List<Object?> get props => [];
}

class GpaCurrentChanged extends GpaEvent {
  final double currentGpa;
  const GpaCurrentChanged(this.currentGpa);

  @override
  List<Object?> get props => [currentGpa];
}

class GpaCompletedCreditsChanged extends GpaEvent {
  final int completedCredits;
  const GpaCompletedCreditsChanged(this.completedCredits);

  @override
  List<Object?> get props => [completedCredits];
}

class GpaRemainingCreditsChanged extends GpaEvent {
  final int remainingCredits;
  const GpaRemainingCreditsChanged(this.remainingCredits);

  @override
  List<Object?> get props => [remainingCredits];
}

class GpaTargetChanged extends GpaEvent {
  final double targetGpa;
  const GpaTargetChanged(this.targetGpa);

  @override
  List<Object?> get props => [targetGpa];
}

// STATE
class GpaState extends Equatable {
  final double currentGpa;
  final int completedCredits;
  final int remainingCredits;
  final double targetGpa;
  final GpaProjectionResult? result;

  const GpaState({
    this.currentGpa = 3.0,
    this.completedCredits = 60,
    this.remainingCredits = 30,
    this.targetGpa = 3.2,
    this.result,
  });

  GpaState copyWith({
    double? currentGpa,
    int? completedCredits,
    int? remainingCredits,
    double? targetGpa,
    GpaProjectionResult? result,
  }) {
    return GpaState(
      currentGpa: currentGpa ?? this.currentGpa,
      completedCredits: completedCredits ?? this.completedCredits,
      remainingCredits: remainingCredits ?? this.remainingCredits,
      targetGpa: targetGpa ?? this.targetGpa,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [
        currentGpa,
        completedCredits,
        remainingCredits,
        targetGpa,
        result,
      ];
}

// BLOC
class GpaBloc extends Bloc<GpaEvent, GpaState> {
  final CalculateGpaUseCase calculateGpaUseCase;

  GpaBloc({required this.calculateGpaUseCase}) : super(const GpaState()) {
    on<GpaCurrentChanged>(_onCurrentChanged);
    on<GpaCompletedCreditsChanged>(_onCompletedCreditsChanged);
    on<GpaRemainingCreditsChanged>(_onRemainingCreditsChanged);
    on<GpaTargetChanged>(_onTargetChanged);

    // Tính toán ban đầu
    _recalculate(state);
  }

  void _onCurrentChanged(GpaCurrentChanged event, Emitter<GpaState> emit) {
    final newState = state.copyWith(currentGpa: event.currentGpa);
    emit(newState.copyWith(result: _calculate(newState)));
  }

  void _onCompletedCreditsChanged(
      GpaCompletedCreditsChanged event, Emitter<GpaState> emit) {
    final newState = state.copyWith(completedCredits: event.completedCredits);
    emit(newState.copyWith(result: _calculate(newState)));
  }

  void _onRemainingCreditsChanged(
      GpaRemainingCreditsChanged event, Emitter<GpaState> emit) {
    final newState = state.copyWith(remainingCredits: event.remainingCredits);
    emit(newState.copyWith(result: _calculate(newState)));
  }

  void _onTargetChanged(GpaTargetChanged event, Emitter<GpaState> emit) {
    final newState = state.copyWith(targetGpa: event.targetGpa);
    emit(newState.copyWith(result: _calculate(newState)));
  }

  void _recalculate(GpaState currentState) {
    add(GpaTargetChanged(currentState.targetGpa));
  }

  GpaProjectionResult _calculate(GpaState s) {
    return calculateGpaUseCase.execute(
      currentGpa: s.currentGpa,
      completedCredits: s.completedCredits,
      remainingCredits: s.remainingCredits,
      targetGpa: s.targetGpa,
    );
  }
}
