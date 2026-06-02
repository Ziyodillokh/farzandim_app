import 'package:flutter/material.dart';

/// Keys must match backend [STAFF_PERMISSIONS] and moderator DTOs.
const List<ModeratorPermGroup> kModeratorPermGroups = [
  ModeratorPermGroup(
    title: 'Foydalanuvchilar boshqaruvi',
    icon: Icons.people_outline_rounded,
    keys: [
      ModeratorPerm('view_users', "Foydalanuvchilarni ko'rish"),
      ModeratorPerm('block_users', 'Foydalanuvchilarni bloklash'),
      ModeratorPerm('warn_users', "Ogohlantirish berish (kelajak)"),
      ModeratorPerm('edit_user_data', "Ma'lumotni tahrirlash"),
    ],
  ),
  ModeratorPermGroup(
    title: 'Kontent moderatsiyasi',
    icon: Icons.movie_outlined,
    keys: [
      ModeratorPerm('view_content', "Kontentni ko'rish"),
      ModeratorPerm('approve_content', 'Kontentni tasdiqlash'),
      ModeratorPerm('reject_content', 'Kontentni rad etish'),
      ModeratorPerm('edit_content', 'Kontentni tahrirlash'),
      ModeratorPerm('delete_content', "Kontentni o'chirish"),
    ],
  ),
  ModeratorPermGroup(
    title: 'Audiokitoblar',
    icon: Icons.headphones_outlined,
    keys: [
      ModeratorPerm('upload_audiobooks', "Yuklash"),
      ModeratorPerm('edit_audiobooks', 'Tahrirlash'),
      ModeratorPerm('delete_audiobooks', "O'chirish"),
      ModeratorPerm('approve_audiobooks', 'Tasdiqlash / moderatsiya'),
    ],
  ),
  ModeratorPermGroup(
    title: 'Konkurslar',
    icon: Icons.emoji_events_outlined,
    keys: [
      ModeratorPerm('create_contest', "Yaratish"),
      ModeratorPerm('edit_contest', 'Tahrirlash / ko‘rish'),
      ModeratorPerm('delete_contest', "O'chirish"),
      ModeratorPerm('select_winner', "G'olibni tanlash"),
    ],
  ),
  ModeratorPermGroup(
    title: 'Bildirishnomalar',
    icon: Icons.notifications_outlined,
    keys: [
      ModeratorPerm('send_notifications', 'Bildirishnoma yuborish'),
    ],
  ),
  ModeratorPermGroup(
    title: 'Analitika',
    icon: Icons.bar_chart_rounded,
    keys: [
      ModeratorPerm('view_analytics', "Ko'rish"),
    ],
  ),
  ModeratorPermGroup(
    title: 'Monetizatsiya',
    icon: Icons.payments_outlined,
    keys: [
      ModeratorPerm('manage_monetization', 'Tarif va promokodlarni boshqarish'),
      ModeratorPerm('view_payments', "To'lovlarni ko'rish"),
    ],
  ),
];

const List<MapEntry<String, String>> kModeratorRoleChoices = [
  MapEntry('super_admin', "Super Admin"),
  MapEntry('finance', 'Moliyachi'),
  MapEntry('content_maker', 'Kontent maker'),
  MapEntry('support', 'Support'),
  MapEntry('custom', 'Ruxsatlardan tanlangan'),
];

class ModeratorPermGroup {
  const ModeratorPermGroup({
    required this.title,
    required this.icon,
    required this.keys,
  });
  final String title;
  final IconData icon;
  final List<ModeratorPerm> keys;
}

class ModeratorPerm {
  const ModeratorPerm(this.id, this.label);
  final String id;
  final String label;
}
