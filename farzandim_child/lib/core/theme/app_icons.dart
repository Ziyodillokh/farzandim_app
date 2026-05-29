// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — ICON SYSTEM (Sprint UI.3, Phosphor Icons)
// ─────────────────────────────────────────────────────────────────────
//
// Phosphor Icons (Bold weight) — Duolingo-style child-friendly.
// Hech bir widget'da to'g'ridan-to'g'ri `PhosphorIcons.X` chaqirilmaydi —
// faqat shu yerdan: `AppIcons.home`, `AppIcons.mic`, ...
//
// Material Icons (Icons.X) ham fallback sifatida saqlanadi — eski kod
// ishlashda davom etadi, yangi kod `AppIcons` ishlatishi kerak.

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AppIcons {
  AppIcons._();

  // ============ NAVIGATION ============
  static const IconData home = PhosphorIconsBold.house;
  static const IconData voice = PhosphorIconsBold.microphone;
  static const IconData location = PhosphorIconsBold.mapPin;
  static const IconData schedule = PhosphorIconsBold.clock;
  static const IconData settings = PhosphorIconsBold.gear;
  static const IconData profile = PhosphorIconsBold.userCircle;

  // ============ VOICE / AUDIO ============
  static const IconData play = PhosphorIconsBold.play;
  static const IconData pause = PhosphorIconsBold.pause;
  static const IconData stop = PhosphorIconsBold.stop;
  static const IconData replay = PhosphorIconsBold.arrowCounterClockwise;
  static const IconData mic = PhosphorIconsBold.microphone;
  static const IconData micOff = PhosphorIconsBold.microphoneSlash;
  static const IconData speaker = PhosphorIconsBold.speakerHigh;
  static const IconData speakerOff = PhosphorIconsBold.speakerX;

  // ============ ACTIONS ============
  static const IconData send = PhosphorIconsBold.paperPlaneTilt;
  static const IconData reply = PhosphorIconsBold.arrowBendUpLeft;
  static const IconData delete = PhosphorIconsBold.trash;
  static const IconData edit = PhosphorIconsBold.pencilSimple;
  static const IconData close = PhosphorIconsBold.x;
  static const IconData check = PhosphorIconsBold.check;
  static const IconData add = PhosphorIconsBold.plus;
  static const IconData back = PhosphorIconsBold.caretLeft;
  static const IconData forward = PhosphorIconsBold.caretRight;
  static const IconData refresh = PhosphorIconsBold.arrowsClockwise;
  static const IconData copy = PhosphorIconsBold.copy;
  static const IconData share = PhosphorIconsBold.shareNetwork;

  // ============ STATUS ============
  static const IconData success = PhosphorIconsBold.checkCircle;
  static const IconData warning = PhosphorIconsBold.warning;
  static const IconData error = PhosphorIconsBold.xCircle;
  static const IconData info = PhosphorIconsBold.info;
  static const IconData block = PhosphorIconsBold.prohibit;

  // ============ NOTIFICATIONS ============
  static const IconData bell = PhosphorIconsBold.bell;
  static const IconData bellOff = PhosphorIconsBold.bellSlash;
  static const IconData message = PhosphorIconsBold.chatCircle;

  // ============ SCHEDULE / TIME ============
  static const IconData scheduleActive = PhosphorIconsBold.timer;
  static const IconData calendar = PhosphorIconsBold.calendarBlank;
  static const IconData hourglass = PhosphorIconsBold.hourglass;

  // ============ LOCATION ============
  static const IconData mapPin = PhosphorIconsBold.mapPin;
  static const IconData geoZone = PhosphorIconsBold.mapTrifold;
  static const IconData navigation = PhosphorIconsBold.navigationArrow;

  // ============ SETTINGS ============
  static const IconData language = PhosphorIconsBold.translate;
  static const IconData privacy = PhosphorIconsBold.shieldCheck;
  static const IconData about = PhosphorIconsBold.info;
  static const IconData logout = PhosphorIconsBold.signOut;
  static const IconData camera = PhosphorIconsBold.camera;
  static const IconData video = PhosphorIconsBold.videoCamera;
  static const IconData image = PhosphorIconsBold.image;
  static const IconData download = PhosphorIconsBold.downloadSimple;
  static const IconData upload = PhosphorIconsBold.uploadSimple;

  // ============ REWARDS (FARO / gamification) ============
  static const IconData star = PhosphorIconsBold.star;
  static const IconData trophy = PhosphorIconsBold.trophy;
  static const IconData streak = PhosphorIconsBold.fire;
  static const IconData gift = PhosphorIconsBold.gift;
  static const IconData medal = PhosphorIconsBold.medal;
  static const IconData heart = PhosphorIconsBold.heart;
  static const IconData crown = PhosphorIconsBold.crown;

  // ============ MISC ============
  static const IconData people = PhosphorIconsBold.users;
  static const IconData family = PhosphorIconsBold.usersThree;
  static const IconData chevronRight = PhosphorIconsBold.caretRight;
  static const IconData chevronLeft = PhosphorIconsBold.caretLeft;
  static const IconData chevronUp = PhosphorIconsBold.caretUp;
  static const IconData chevronDown = PhosphorIconsBold.caretDown;
  static const IconData expandMore = PhosphorIconsBold.caretDown;
  static const IconData expandLess = PhosphorIconsBold.caretUp;
  static const IconData search = PhosphorIconsBold.magnifyingGlass;
  static const IconData filter = PhosphorIconsBold.funnel;
  static const IconData menu = PhosphorIconsBold.list;
  static const IconData moreVert = PhosphorIconsBold.dotsThreeVertical;
}
