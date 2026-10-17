import 'package:equatable/equatable.dart';

/// Pure domain entity representing a lecture note.
/// Contains no Flutter UI dependencies.
class LectureNote extends Equatable {
  final String id;
  final String subjectId;
  final String? slotId;
  final String title;
  final String bodyText;
  final List<String> videoPaths;
  final List<String> imagePaths;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  LectureNote({
    required this.id,
    required this.subjectId,
    this.slotId,
    required this.title,
    required this.bodyText,
    String? videoPath,
    List<String>? videoPaths,
    this.imagePaths = const [],
    this.location,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  }) : videoPaths = videoPaths ?? (videoPath != null ? [videoPath] : const []);

  /// Backward-compatibility getter for single video access.
  String? get videoPath => videoPaths.isNotEmpty ? videoPaths.first : null;

  LectureNote copyWith({
    String? id,
    String? subjectId,
    String? slotId,
    String? title,
    String? bodyText,
    String? videoPath,
    List<String>? videoPaths,
    bool clearVideo = false,
    List<String>? imagePaths,
    String? location,
    bool clearLocation = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    List<String> resolvedVideos;
    if (clearVideo) {
      resolvedVideos = const [];
    } else if (videoPaths != null) {
      resolvedVideos = videoPaths;
    } else if (videoPath != null) {
      resolvedVideos = [videoPath];
    } else {
      resolvedVideos = this.videoPaths;
    }

    return LectureNote(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      slotId: slotId ?? this.slotId,
      title: title ?? this.title,
      bodyText: bodyText ?? this.bodyText,
      videoPaths: resolvedVideos,
      imagePaths: imagePaths ?? this.imagePaths,
      location: clearLocation ? null : (location ?? this.location),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        slotId,
        title,
        bodyText,
        videoPaths,
        imagePaths,
        location,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
