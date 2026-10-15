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

  // Security Feature (S01)
  static const String lock = '/lock';
}
