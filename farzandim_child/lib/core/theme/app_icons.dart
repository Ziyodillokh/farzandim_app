// ─────────────────────────────────────────────────────────────────────
// FARZANDIM CHILD — ICON SYSTEM
// ─────────────────────────────────────────────────────────────────────
//
// Material Icons (Icons.X) ishlatiladi. Hech bir widget'da to'g'ridan-to'g'ri
// `Icons.X` chaqirilmaydi — faqat shu yerdan: `AppIcons.home`, `AppIcons.mic`...
//
// Eslatma: ilgari Phosphor Icons ishlatilardi, lekin u paket (2.1.0) Flutter
// 3.27+ (IconData `final class`) bilan mos kelmaydi va yangilanmagan. Shu sabab
// barcha ikonalar Material'ning ekvivalentlariga ko'chirildi (paketsiz).

import 'package:flutter/material.dart';

class AppIcons {
  AppIcons._();

  // ============ NAVIGATION ============
  static const IconData home = Icons.home_rounded;
  static const IconData voice = Icons.mic_rounded;
  static const IconData location = Icons.location_on_rounded;
  static const IconData schedule = Icons.schedule_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData profile = Icons.account_circle_rounded;

  // ============ VOICE / AUDIO ============
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData stop = Icons.stop_rounded;
  static const IconData replay = Icons.replay_rounded;
  static const IconData mic = Icons.mic_rounded;
  static const IconData micOff = Icons.mic_off_rounded;
  static const IconData speaker = Icons.volume_up_rounded;
  static const IconData speakerOff = Icons.volume_off_rounded;

  // ============ ACTIONS ============
  static const IconData send = Icons.send_rounded;
  static const IconData reply = Icons.reply_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData back = Icons.chevron_left_rounded;
  static const IconData forward = Icons.chevron_right_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData share = Icons.share_rounded;

  // ============ STATUS ============
  static const IconData success = Icons.check_circle_rounded;
  static const IconData warning = Icons.warning_rounded;
  static const IconData error = Icons.cancel_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData block = Icons.block_rounded;

  // ============ NOTIFICATIONS ============
  static const IconData bell = Icons.notifications_rounded;
  static const IconData bellOff = Icons.notifications_off_rounded;
  static const IconData message = Icons.chat_bubble_rounded;

  // ============ SCHEDULE / TIME ============
  static const IconData scheduleActive = Icons.timer_rounded;
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData hourglass = Icons.hourglass_empty_rounded;

  // ============ LOCATION ============
  static const IconData mapPin = Icons.location_on_rounded;
  static const IconData geoZone = Icons.map_rounded;
  static const IconData navigation = Icons.navigation_rounded;

  // ============ SETTINGS ============
  static const IconData language = Icons.translate_rounded;
  static const IconData privacy = Icons.verified_user_rounded;
  static const IconData about = Icons.info_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData camera = Icons.camera_alt_rounded;
  static const IconData video = Icons.videocam_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData upload = Icons.upload_rounded;

  // ============ REWARDS (FARO / gamification) ============
  static const IconData star = Icons.star_rounded;
  static const IconData trophy = Icons.emoji_events_rounded;
  static const IconData streak = Icons.local_fire_department_rounded;
  static const IconData gift = Icons.card_giftcard_rounded;
  static const IconData medal = Icons.military_tech_rounded;
  static const IconData heart = Icons.favorite_rounded;
  static const IconData crown = Icons.workspace_premium_rounded;

  // ============ MISC ============
  static const IconData people = Icons.people_rounded;
  static const IconData family = Icons.groups_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData chevronUp = Icons.keyboard_arrow_up_rounded;
  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData expandLess = Icons.expand_less_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_alt_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData moreVert = Icons.more_vert_rounded;
}
