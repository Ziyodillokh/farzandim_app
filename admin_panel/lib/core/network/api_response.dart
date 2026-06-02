import '../errors/app_exceptions.dart';

/// Normalized API outcome (optional envelope for repositories).
final class ApiResponse<T> {
  const ApiResponse._({required this.success, this.data, this.error});

  const ApiResponse.ok(T data) : this._(success: true, data: data);

  const ApiResponse.fail(AppException error) : this._(success: false, error: error);

  final bool success;
  final T? data;
  final AppException? error;

  R when<R>({required R Function(T data) ok, required R Function(AppException e) err}) {
    if (success && data != null) {
      return ok(data as T);
    }
    return err(error ?? const AuthException('Unknown error'));
  }
}
