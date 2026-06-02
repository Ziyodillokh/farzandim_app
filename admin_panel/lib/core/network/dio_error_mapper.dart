import 'package:dio/dio.dart';

import '../errors/app_exceptions.dart';

AppException mapDioException(DioException e) {
  final type = e.type;
  if (type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout) {
    return NetworkException('Request timed out', cause: e, kind: NetworkFailureKind.timeout);
  }
  if (type == DioExceptionType.connectionError) {
    return NetworkException('No connection', cause: e, kind: NetworkFailureKind.noConnection);
  }
  if (type == DioExceptionType.cancel) {
    return NetworkException('Cancelled', cause: e, kind: NetworkFailureKind.cancelled);
  }
  final code = e.response?.statusCode;
  if (code == 401 || code == 403) {
    return AuthException('Unauthorized', cause: e, statusCode: code);
  }
  if (code != null && code >= 500) {
    return ServerException('Server error', cause: e, statusCode: code);
  }
  if (code != null && code >= 400) {
    return ServerException('Request failed', cause: e, statusCode: code);
  }
  return NetworkException(e.message ?? 'Network error', cause: e, kind: NetworkFailureKind.unknown);
}
