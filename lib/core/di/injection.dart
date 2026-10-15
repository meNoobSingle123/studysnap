import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/notes/data/repositories/in_memory_note_repository.dart';
import '../../features/notes/domain/repositories/note_repository.dart';
import '../../features/notes/domain/usecases/get_note_by_id_usecase.dart';
import '../../features/notes/domain/usecases/save_note_usecase.dart';
import '../../features/notes/presentation/bloc/canvas_bloc.dart';
import '../../features/notes/presentation/bloc/note_editor_bloc.dart';
import '../network/dio_client.dart';
import '../security/bloc/auth_lock_bloc.dart';
import '../security/key_storage_service.dart';

/// Global service locator instance.
final getIt = GetIt.instance;

/// Initialize and register all core dependencies and feature modules.
Future<void> configureDependencies() async {
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

  // Notes Module (InMemory for independent testing)
  getIt.registerLazySingleton<NoteRepository>(() => InMemoryNoteRepository());
  getIt.registerLazySingleton<GetNoteByIdUseCase>(
    () => GetNoteByIdUseCase(getIt<NoteRepository>()),
  );
  getIt.registerLazySingleton<SaveNoteUseCase>(
    () => SaveNoteUseCase(getIt<NoteRepository>()),
  );
  getIt.registerFactory<NoteEditorBloc>(
    () => NoteEditorBloc(
      getNoteByIdUseCase: getIt<GetNoteByIdUseCase>(),
      saveNoteUseCase: getIt<SaveNoteUseCase>(),
    ),
  );
  getIt.registerFactory<CanvasBloc>(() => CanvasBloc());
}
