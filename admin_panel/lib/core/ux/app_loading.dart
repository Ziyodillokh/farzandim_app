import 'package:flutter/foundation.dart';

/// Global in-flight API / refresh counter for a minimal blocking overlay.
final class AppLoading extends ChangeNotifier {
  AppLoading._();
  static final AppLoading instance = AppLoading._();

  int _depth = 0;

  bool get isBlocking => _depth > 0;

  void begin() {
    _depth++;
    notifyListeners();
  }

  void end() {
    if (_depth > 0) {
      _depth--;
      notifyListeners();
    }
  }
}
