import 'package:dio/dio.dart';

class ExamService {
  ExamService(this._dio);

  final Dio _dio;

  Dio get client => _dio;
}
