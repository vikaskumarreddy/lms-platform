// Native (Android/iOS) implementation of OfflineManager helpers.
// This file is only compiled on non-web platforms.
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kDownloadedVideosPrefKey = 'offline_downloaded_videos';

Future<String> _getOfflineDirectoryPath() async {
  final dir = await getApplicationDocumentsDirectory();
  final offlineDir = Directory('${dir.path}/offline_lessons');
  if (!offlineDir.existsSync()) {
    offlineDir.createSync(recursive: true);
  }
  return offlineDir.path;
}

Future<String> getLocalVideoFilePath(int lessonId) async {
  final offlinePath = await _getOfflineDirectoryPath();
  return '$offlinePath/lesson_$lessonId.mp4';
}

Future<bool> isLessonVideoDownloaded(int lessonId) async {
  final filePath = await getLocalVideoFilePath(lessonId);
  final file = File(filePath);
  return file.existsSync() && file.lengthSync() > 1024;
}

Future<File?> downloadLessonVideo(
  int lessonId,
  String videoUrl, {
  void Function(double progress)? onProgress,
}) async {
  try {
    final targetPath = await getLocalVideoFilePath(lessonId);
    final targetFile = File(targetPath);

    final client = http.Client();
    final request = http.Request('GET', Uri.parse(videoUrl));
    final response = await client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download video: HTTP ${response.statusCode}');
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;
    final sink = targetFile.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        onProgress(receivedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();

    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_kDownloadedVideosPrefKey) ?? [];
    if (!list.contains(lessonId.toString())) {
      list.add(lessonId.toString());
      await prefs.setStringList(_kDownloadedVideosPrefKey, list);
    }

    return targetFile;
  } catch (e) {
    print('OfflineManager download error: $e');
    return null;
  }
}

Future<void> deleteDownloadedLessonVideo(int lessonId) async {
  try {
    final targetPath = await getLocalVideoFilePath(lessonId);
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_kDownloadedVideosPrefKey) ?? [];
    list.remove(lessonId.toString());
    await prefs.setStringList(_kDownloadedVideosPrefKey, list);
  } catch (e) {
    print('Error deleting downloaded lesson video: $e');
  }
}

Future<String> saveTempPdf(List<int> bytes, [String? prefix]) async {
  final dir = await getTemporaryDirectory();
  final filename = '${prefix ?? 'lesson_pdf'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> _getCachedDocsDirectoryPath() async {
  final dir = await getApplicationDocumentsDirectory();
  final docsDir = Directory('${dir.path}/cached_docs');
  if (!docsDir.existsSync()) {
    docsDir.createSync(recursive: true);
  }
  return docsDir.path;
}

Future<String> getCachedPdfFilePath(int lessonId) async {
  final docsPath = await _getCachedDocsDirectoryPath();
  return '$docsPath/lesson_pdf_$lessonId.pdf';
}

Future<bool> isPdfCached(int lessonId) async {
  final path = await getCachedPdfFilePath(lessonId);
  final file = File(path);
  return file.existsSync() && file.lengthSync() > 100;
}

Future<String> saveCachedPdf(int lessonId, List<int> bytes) async {
  final path = await getCachedPdfFilePath(lessonId);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

