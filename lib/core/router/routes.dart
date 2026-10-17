/// Application route paths and names.
abstract final class Routes {
  static const String home = '/';
  static const String timetable = '/timetable';
  static const String notes = '/notes';
  static const String tools = '/tools';

  // Notes Feature
  static const String noteEditor = '/notes/edit/:id';
  static String noteEdit(String id) => '/notes/edit/$id';
  static const String canvas = '/notes/canvas';
  static String canvasRoute({String? noteId}) =>
      noteId != null ? '/notes/canvas?noteId=$noteId' : '/notes/canvas';

  // Timetable Feature (Huy)
  static const String gpaProjection = '/timetable/gpa';
  static const String slotDetail = '/timetable/slot/:id';
  static String slotDetailRoute(String id) => '/timetable/slot/$id';

  // Security Feature (S01)
  static const String lock = '/lock';

  // Scanner & Camera Feature (Huy - S08)
  static const String scanner = '/scanner';

  // Export PDF Feature (Huy - S09)
  static const String pdfExport = '/export/pdf';
  static String pdfExportRoute({String? noteId}) =>
      noteId != null ? '/export/pdf?noteId=$noteId' : '/export/pdf';

  // Notifications Feature (Huy - CĐ 7)
  static const String notifications = '/settings/notifications';

  // OCR Scanner Feature (Khiêm - CĐ 12)
  static const String ocrScanner = '/ocr/scanner';
}

