import 'package:equatable/equatable.dart';

import '../../../../core/l10n/strings.dart';
import '../entities/qr_document_link.dart';

sealed class QrParseResult extends Equatable {
  const QrParseResult();

  @override
  List<Object?> get props => [];
}

class QrParseSuccess extends QrParseResult {
  final QrDocumentLink link;

  const QrParseSuccess(this.link);

  @override
  List<Object?> get props => [link];
}

class QrParseFailure extends QrParseResult {
  final String errorMessage;

  const QrParseFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}

/// Pure domain usecase to parse and validate StudySnap document QR codes according to SRS 7.3.
/// Expected format: `studysnap://doc?url=<URL https da ma hoa>`
class ParseQrCodeUseCase {
  const ParseQrCodeUseCase();

  QrParseResult call(String? rawContent) {
    if (rawContent == null || rawContent.trim().isEmpty) {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    final trimmed = rawContent.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    // 1. Must use 'studysnap' scheme
    if (uri.scheme.toLowerCase() != 'studysnap') {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    // 2. Host or path must indicate 'doc'
    final host = uri.host.toLowerCase();
    final path = uri.path.replaceAll('/', '').toLowerCase();
    if (host != 'doc' && path != 'doc') {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    // 3. Extract 'url' query parameter
    final targetUrlParam = uri.queryParameters['url'];
    if (targetUrlParam == null || targetUrlParam.trim().isEmpty) {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    final decodedUrl = Uri.decodeFull(targetUrlParam.trim());
    final targetUri = Uri.tryParse(decodedUrl);
    if (targetUri == null) {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    // 4. Target URL MUST be HTTPS according to SRS 7.3
    if (targetUri.scheme.toLowerCase() != 'https') {
      return const QrParseFailure(AppStrings.insecureHttpBlocked);
    }

    // 5. Host/Domain must be valid
    final domain = targetUri.host;
    if (domain.isEmpty) {
      return const QrParseFailure(AppStrings.invalidQrCode);
    }

    return QrParseSuccess(
      QrDocumentLink(
        originalQrCode: trimmed,
        documentUrl: decodedUrl,
        domain: domain,
      ),
    );
  }
}
