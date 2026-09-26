// Web / non-io stub for OfflineManager.
// File I/O is not supported on the web platform.

Future<String> getLocalVideoFilePath(int lessonId) async => '';

Future<bool> isLessonVideoDownloaded(int lessonId) async => false;

Future<dynamic> downloadLessonVideo(
  int lessonId,
  String videoUrl, {
  void Function(double progress)? onProgress,
}) async => null;

Future<void> deleteDownloadedLessonVideo(int lessonId) async {}

Future<String> saveTempPdf(List<int> bytes, [String? prefix]) async => '';

Future<String> getCachedPdfFilePath(int lessonId) async => '';
Future<bool> isPdfCached(int lessonId) async => false;
Future<String> saveCachedPdf(int lessonId, List<int> bytes) async => '';

