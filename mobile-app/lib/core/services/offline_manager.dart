import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineManager {
  static final OfflineManager instance = OfflineManager._internal();
  OfflineManager._internal();

  static const String _kDownloadedVideosPrefKey = 'offline_downloaded_videos';

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
    return '$offlinePath/lesson_${lessonId}.mp4';
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

      // Record in SharedPreferences
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

  Future<List<int>> getDownloadedLessonIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_kDownloadedVideosPrefKey) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }
}
