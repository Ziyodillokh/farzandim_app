/// Base for API / network failures surfaced to UI or repositories.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, this.kind = NetworkFailureKind.unknown});

  final NetworkFailureKind kind;
}

enum NetworkFailureKind { timeout, noConnection, serverError, cancelled, unknown }

final class AuthException extends AppException {
  const AuthException(super.message, {super.cause, this.statusCode});

  final int? statusCode;
}

final class ServerException extends AppException {
  const ServerException(super.message, {super.cause, this.statusCode});

  final int? statusCode;
}
