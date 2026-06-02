import 'secure_token_storage.dart';
import 'secure_token_storage_stub.dart'
    if (dart.library.io) 'secure_token_storage_io.dart'
    if (dart.library.html) 'secure_token_storage_web.dart' as impl;

Future<SecureTokenStorage> createSecureTokenStorage() =>
    impl.createSecureTokenStorage();
