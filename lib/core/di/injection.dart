import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/notes/data/repositories/in_memory_note_repository.dart';
import '../../features/notes/domain/repositories/note_repository.dart';
import '../../features/notes/domain/usecases/delete_note_usecase.dart';
import '../../features/notes/domain/usecases/get_all_notes_usecase.dart';
import '../../features/notes/domain/usecases/get_note_by_id_usecase.dart';
import '../../features/notes/domain/usecases/save_note_usecase.dart';
import '../../features/notes/domain/usecases/watch_all_notes_usecase.dart';
import '../../features/notes/presentation/bloc/canvas_bloc.dart';
import '../../features/notes/presentation/bloc/note_editor_bloc.dart';
import '../../features/notes/presentation/bloc/note_list_bloc.dart';
import '../../features/timetable/data/datasources/timetable_local_datasource.dart';
import '../../features/timetable/data/repositories/timetable_repository_impl.dart';
import '../../features/timetable/domain/repositories/timetable_repository.dart';
import '../../features/timetable/domain/usecases/calculate_gpa_usecase.dart';
import '../../features/timetable/domain/usecases/get_subjects_usecase.dart';
import '../../features/timetable/domain/usecases/get_timetable_slots_usecase.dart';
import '../../features/timetable/domain/usecases/save_subject_usecase.dart';
import '../network/dio_client.dart';
import '../security/bloc/auth_lock_bloc.dart';
import '../security/key_storage_service.dart';

import 'dart:io';

/// Global service locator instance.
final getIt = GetIt.instance;

/// Initialize and register all core dependencies and feature modules.
Future<void> configureDependencies({bool isTest = false}) async {
  // 1. Initialize Hive Flutter (hoặc temp dir trong test)
  if (isTest) {
    Hive.init(Directory.systemTemp.createTempSync().path);
  } else {
    try {
      await Hive.initFlutter();
    } catch (_) {
      Hive.init(Directory.systemTemp.createTempSync().path);
    }
  }

  // Core security & storage
  getIt.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  getIt.registerLazySingleton<KeyStorageService>(
    () => KeyStorageService(storage: getIt<FlutterSecureStorage>()),
  );
  getIt.registerLazySingleton<LocalAuthentication>(
    () => LocalAuthentication(),
  );
  getIt.registerLazySingleton<AuthLockBloc>(
    () => AuthLockBloc(localAuth: getIt<LocalAuthentication>()),
  );

  // Core network
  getIt.registerLazySingleton<DioClient>(() => DioClient());

  // Timetable Module (Huy phụ trách)
  final timetableLocalDataSource = TimetableLocalDataSourceImpl(
    keyStorageService: getIt<KeyStorageService>(),
  );
  await timetableLocalDataSource.init();
  getIt.registerSingleton<TimetableLocalDataSource>(timetableLocalDataSource);

  getIt.registerLazySingleton<TimetableRepository>(
    () => TimetableRepositoryImpl(
      localDataSource: getIt<TimetableLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<GetTimetableSlotsUseCase>(
    () => GetTimetableSlotsUseCase(getIt<TimetableRepository>()),
  );
  getIt.registerLazySingleton<GetSubjectsUseCase>(
    () => GetSubjectsUseCase(getIt<TimetableRepository>()),
  );
  getIt.registerLazySingleton<SaveSubjectUseCase>(
    () => SaveSubjectUseCase(getIt<TimetableRepository>()),
  );
  getIt.registerLazySingleton<CalculateGpaUseCase>(
    () => const CalculateGpaUseCase(),
  );

  // Notes Module (InMemory for independent testing)
  getIt.registerLazySingleton<NoteRepository>(
    () => InMemoryNoteRepository(seedMockData: !isTest),
  );
  getIt.registerLazySingleton<GetNoteByIdUseCase>(
    () => GetNoteByIdUseCase(getIt<NoteRepository>()),
  );
  getIt.registerLazySingleton<SaveNoteUseCase>(
    () => SaveNoteUseCase(getIt<NoteRepository>()),
  );
  getIt.registerLazySingleton<GetAllNotesUseCase>(
    () => GetAllNotesUseCase(getIt<NoteRepository>()),
  );
  getIt.registerLazySingleton<WatchAllNotesUseCase>(
    () => WatchAllNotesUseCase(getIt<NoteRepository>()),
  );
  getIt.registerLazySingleton<DeleteNoteUseCase>(
    () => DeleteNoteUseCase(getIt<NoteRepository>()),
  );
  getIt.registerFactory<NoteEditorBloc>(
    () => NoteEditorBloc(
      getNoteByIdUseCase: getIt<GetNoteByIdUseCase>(),
      saveNoteUseCase: getIt<SaveNoteUseCase>(),
    ),
  );
  getIt.registerFactory<NoteListBloc>(
    () => NoteListBloc(
      watchAllNotesUseCase: getIt<WatchAllNotesUseCase>(),
      deleteNoteUseCase: getIt<DeleteNoteUseCase>(),
      getSubjectsUseCase: getIt<GetSubjectsUseCase>(),
    ),
  );
  getIt.registerFactory<CanvasBloc>(() => CanvasBloc());
}

