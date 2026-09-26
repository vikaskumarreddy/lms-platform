import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// dart:io and path_provider are mobile-only — import conditionally so web builds don't crash.
// ignore: avoid_web_libraries_in_flutter
import 'offline_manager_stub.dart'
    if (dart.library.io) 'offline_manager_native.dart' as _native;

class OfflineManager {
  static final OfflineManager instance = OfflineManager._internal();
  OfflineManager._internal();

  static const String _kDownloadedVideosPrefKey = 'offline_downloaded_videos';

  Future<String> getLocalVideoFilePath(int lessonId) async {
    if (kIsWeb) return '';
    return _native.getLocalVideoFilePath(lessonId);
  }

  Future<bool> isLessonVideoDownloaded(int lessonId) async {
    if (kIsWeb) return false;
    return _native.isLessonVideoDownloaded(lessonId);
  }

  Future<dynamic> downloadLessonVideo(
    int lessonId,
    String videoUrl, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return null;
    return _native.downloadLessonVideo(lessonId, videoUrl, onProgress: onProgress);
  }

  Future<void> deleteDownloadedLessonVideo(int lessonId) async {
    if (kIsWeb) return;
    await _native.deleteDownloadedLessonVideo(lessonId);
  }

  Future<String> saveTempPdf(List<int> bytes, [String? prefix]) async {
    if (kIsWeb) return '';
    return _native.saveTempPdf(bytes, prefix);
  }

  Future<String> getCachedPdfFilePath(int lessonId) async {
    if (kIsWeb) return '';
    return _native.getCachedPdfFilePath(lessonId);
  }

  Future<bool> isPdfCached(int lessonId) async {
    if (kIsWeb) return false;
    return _native.isPdfCached(lessonId);
  }

  Future<String> saveCachedPdf(int lessonId, List<int> bytes) async {
    if (kIsWeb) return '';
    return _native.saveCachedPdf(lessonId, bytes);
  }

  Future<List<int>> getDownloadedLessonIds() async {
    if (kIsWeb) return [];
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_kDownloadedVideosPrefKey) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }
}
