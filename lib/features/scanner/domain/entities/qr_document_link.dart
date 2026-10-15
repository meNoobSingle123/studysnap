import 'package:equatable/equatable.dart';

/// Pure domain entity representing a valid document link parsed from StudySnap QR.
class QrDocumentLink extends Equatable {
  final String originalQrCode;
  final String documentUrl;
  final String domain;

  const QrDocumentLink({
    required this.originalQrCode,
    required this.documentUrl,
    required this.domain,
  });

  @override
  List<Object?> get props => [originalQrCode, documentUrl, domain];
}
