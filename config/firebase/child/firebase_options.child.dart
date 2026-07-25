// ─────────────────────────────────────────────────────────────────────
// firebase_options.dart — farzandim_child (Play paketi: com.farzandim.growth)
// ─────────────────────────────────────────────────────────────────────
//
// NEGA BU FAYL REPODA: bola ilovasining Play uchun paketi `com.farzandim.child`
// dan `com.farzandim.growth` ga o'zgardi (eski paket Play'da band edi).
// FIREBASE_CONFIGS_B64 secret'idagi eski `firebase_options.dart` hamon eski
// paketning appId'sini beradi — u bilan FCM ro'yxatdan o'tishi ishlamaydi.
// Shuning uchun CI secret'ni ochgandan KEYIN shu fayl ustiga nusxalanadi
// (workflow'dagi "Override child Firebase config" qadami).
//
// Qiymatlar Firebase loyihasidan (farzandim-mvp) olingan — Android ilova
// `com.farzandim.growth` sifatida ro'yxatdan o'tgan.
// MAXFIY EMAS: bu qiymatlar har bir APK ichida ochiq turadi (Firebase
// xavfsizligi kalit sirligiga emas, Security Rules'ga tayanadi).

// ignore_for_file: public_member_api_docs, type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCVQqj1-NIQwp9G566CS65ruw53Nzx6pDE',
    appId: '1:163835260058:web:8936a41210a9db8fd30323',
    messagingSenderId: '163835260058',
    projectId: 'farzandim-mvp',
    authDomain: 'farzandim-mvp.firebaseapp.com',
    databaseURL:
        'https://farzandim-mvp-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'farzandim-mvp.firebasestorage.app',
  );

  // Play uchun YANGI paket — com.farzandim.growth.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVQqj1-NIQwp9G566CS65ruw53Nzx6pDE',
    appId: '1:163835260058:android:72731351799f7f7bd30323',
    messagingSenderId: '163835260058',
    projectId: 'farzandim-mvp',
    databaseURL:
        'https://farzandim-mvp-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'farzandim-mvp.firebasestorage.app',
  );

  // iOS hozircha eski bundle (com.farzandim.child) — App Store'ga
  // yuborilmayapti, tegilmadi.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCVQqj1-NIQwp9G566CS65ruw53Nzx6pDE',
    appId: '1:163835260058:ios:7b98e6fe27d4840bd30323',
    messagingSenderId: '163835260058',
    projectId: 'farzandim-mvp',
    databaseURL:
        'https://farzandim-mvp-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'farzandim-mvp.firebasestorage.app',
    iosBundleId: 'com.farzandim.child',
  );

  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = web;
  static const FirebaseOptions linux = web;
}
