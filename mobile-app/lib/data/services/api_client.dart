import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

class ApiClient {
  static String get baseUrl => AppConfig.apiBaseUrl;
  late Dio dio;
  late SharedPreferences prefs;

  ApiClient() {
    dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30), headers: {'Content-Type': 'application/json'}));
    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        handler.next(e);
      },
    ));
  }

  Future<Response> get(String path) => dio.get(path);
  Future<Response> post(String path, {Map<String, dynamic>? data}) => dio.post(path, data: data);
  Future<Response> put(String path, {Map<String, dynamic>? data}) => dio.put(path, data: data);
  Future<Response> delete(String path) => dio.delete(path);
}
