import 'package:equatable/equatable.dart';

/// Pure domain entity representing a lecture note.
/// Contains no Flutter UI dependencies.
class LectureNote extends Equatable {
  final String id;
  final String subjectId;
  final String? slotId;
  final String title;
  final String bodyText;
  final String? videoPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const LectureNote({
    required this.id,
    required this.subjectId,
    this.slotId,
    required this.title,
    required this.bodyText,
    this.videoPath,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  LectureNote copyWith({
    String? id,
    String? subjectId,
    String? slotId,
    String? title,
    String? bodyText,
    String? videoPath,
    bool clearVideo = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return LectureNote(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      slotId: slotId ?? this.slotId,
      title: title ?? this.title,
      bodyText: bodyText ?? this.bodyText,
      videoPath: clearVideo ? null : (videoPath ?? this.videoPath),
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
        videoPath,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}
