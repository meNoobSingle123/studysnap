import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/lecture_note.dart';
import '../../domain/usecases/get_note_by_id_usecase.dart';
import '../../domain/usecases/save_note_usecase.dart';
import 'note_editor_event.dart';
import 'note_editor_state.dart';

class NoteEditorBloc extends Bloc<NoteEditorEvent, NoteEditorState> {
  final GetNoteByIdUseCase getNoteByIdUseCase;
  final SaveNoteUseCase saveNoteUseCase;
  final Duration autoSaveDuration;

  Timer? _debounceTimer;

  NoteEditorBloc({
    required this.getNoteByIdUseCase,
    required this.saveNoteUseCase,
    this.autoSaveDuration = const Duration(seconds: 2),
  }) : super(const NoteEditorInitial()) {
    on<LoadNote>(_onLoadNote);
    on<UpdateContent>(_onUpdateContent);
    on<AttachVideo>(_onAttachVideo);
    on<AddVideo>(_onAddVideo);
    on<RemoveVideo>(_onRemoveVideo);
    on<UpdateLocation>(_onUpdateLocation);
    on<AddImage>(_onAddImage);
    on<RemoveImage>(_onRemoveImage);
    on<UpdateSubject>(_onUpdateSubject);
    on<SaveNote>(_onSaveNote);
  }

  Future<void> _onLoadNote(LoadNote event, Emitter<NoteEditorState> emit) async {
    _debounceTimer?.cancel();
    emit(const NoteEditorLoading());
    try {
      final existing = await getNoteByIdUseCase(event.id);
      if (emit.isDone) return;

      if (existing != null) {
        emit(NoteEditorLoaded(note: existing));
      } else {
        final now = DateTime.now();
        final newDraft = LectureNote(
          id: event.id,
          subjectId: event.subjectId ?? 'general',
          slotId: event.slotId,
          title: '',
          bodyText: '',
          createdAt: now,
          updatedAt: now,
        );
        emit(NoteEditorLoaded(note: newDraft));
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(NoteEditorFailure(e.toString()));
      }
    }
  }

  void _onUpdateContent(UpdateContent event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      final updatedNote = current.note.copyWith(
        title: event.title ?? current.note.title,
        bodyText: event.bodyText ?? current.note.bodyText,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onAttachVideo(AttachVideo event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      final updatedNote = current.note.copyWith(
        videoPath: event.videoPath,
        clearVideo: event.videoPath == null,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onAddVideo(AddVideo event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      if (current.note.videoPaths.contains(event.videoPath)) return;
      final newVideos = List<String>.from(current.note.videoPaths)..add(event.videoPath);
      final updatedNote = current.note.copyWith(
        videoPaths: newVideos,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onRemoveVideo(RemoveVideo event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      final newVideos = List<String>.from(current.note.videoPaths)..remove(event.videoPath);
      final updatedNote = current.note.copyWith(
        videoPaths: newVideos,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onUpdateLocation(UpdateLocation event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      final updatedNote = current.note.copyWith(
        location: event.location,
        clearLocation: event.location == null,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onAddImage(AddImage event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      if (current.note.imagePaths.contains(event.imagePath)) return;
      final newImages = List<String>.from(current.note.imagePaths)..add(event.imagePath);
      final updatedNote = current.note.copyWith(
        imagePaths: newImages,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onRemoveImage(RemoveImage event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      final newImages = List<String>.from(current.note.imagePaths)..remove(event.imagePath);
      final updatedNote = current.note.copyWith(
        imagePaths: newImages,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _onUpdateSubject(UpdateSubject event, Emitter<NoteEditorState> emit) {
    final current = state;
    if (current is NoteEditorLoaded) {
      final updatedNote = current.note.copyWith(
        subjectId: event.subjectId,
        updatedAt: DateTime.now(),
      );
      emit(current.copyWith(
        note: updatedNote,
        isSaveSuccess: false,
        hasUnsavedChanges: true,
      ));

      _triggerDebouncedSave();
    }
  }

  void _triggerDebouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(autoSaveDuration, () {
      if (!isClosed) {
        add(const SaveNote());
      }
    });
  }

  Future<void> _onSaveNote(SaveNote event, Emitter<NoteEditorState> emit) async {
    _debounceTimer?.cancel();
    final current = state;
    if (current is NoteEditorLoaded) {
      emit(current.copyWith(isSaving: true, isSaveSuccess: false));
      try {
        final noteToSave = current.note.copyWith(updatedAt: DateTime.now());
        await saveNoteUseCase(noteToSave);
        if (!emit.isDone) {
          emit(current.copyWith(
            note: noteToSave,
            isSaving: false,
            isSaveSuccess: true,
            hasUnsavedChanges: false,
          ));
        }
      } catch (e) {
        if (!emit.isDone) {
          emit(NoteEditorFailure(e.toString()));
        }
      }
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
