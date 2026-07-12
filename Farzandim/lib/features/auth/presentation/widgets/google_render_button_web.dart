// Google rasmiy tugmasi — WEB implementatsiyasi.
//
// Web'da `google_sign_in`ning `signIn()` metodi ID token BERMAYDI (GIS
// migratsiyasi cheklovi). Yagona rasmiy yo'l — Google render qilgan
// tugma: bosilganda credential (ID token JWT) callback keladi va plugin
// `onCurrentUserChanged` orqali idToken'li akkauntni beradi.

import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;

/// Google'ning rasmiy "Sign in with Google" tugmasi (iframe).
Widget googleRenderButton() {
  return web_only.renderButton(
    configuration: web_only.GSIButtonConfiguration(
      theme: web_only.GSIButtonTheme.filledBlue,
      size: web_only.GSIButtonSize.large,
      shape: web_only.GSIButtonShape.pill,
      text: web_only.GSIButtonText.continueWith,
    ),
  );
}
