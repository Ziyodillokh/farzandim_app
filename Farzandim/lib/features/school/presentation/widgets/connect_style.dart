// Maktab xodimi rollari va xabar mavzulari uchun rang va ikonlar.

import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:solar_icons/solar_icons.dart';

Color roleColor(StaffRole role) => switch (role) {
  StaffRole.homeroom => SK.sky,
  StaffRole.director => SK.amber,
  StaffRole.admin => SK.teal,
  StaffRole.psychologist => SK.green,
  StaffRole.teacher => const Color(0xFF7FB2FF),
  StaffRole.unknown => SK.dim,
};

IconData roleIcon(StaffRole role) => switch (role) {
  StaffRole.homeroom => SolarIconsBold.usersGroupRounded,
  StaffRole.director => SolarIconsBold.crownMinimalistic,
  StaffRole.admin => SolarIconsBold.caseRound,
  StaffRole.psychologist => SolarIconsBold.handHeart,
  StaffRole.teacher => SolarIconsBold.squareAcademicCap,
  StaffRole.unknown => SolarIconsBold.user,
};

/// E'lon muallifi roli ("DIRECTOR" …) → [StaffRole].
StaffRole roleOfApi(String? role) => StaffRole.fromApi(role);

IconData topicIcon(ContactTopic topic) => switch (topic) {
  ContactTopic.absence => SolarIconsBold.stethoscope,
  ContactTopic.earlyPickup => SolarIconsBold.walking,
  ContactTopic.homework => SolarIconsBold.notebook,
  ContactTopic.progress => SolarIconsBold.graphUp,
  ContactTopic.meeting => SolarIconsBold.calendarMark,
  ContactTopic.behavior => SolarIconsBold.userSpeak,
  ContactTopic.wellbeing => SolarIconsBold.smileCircle,
  ContactTopic.bullying => SolarIconsBold.shieldWarning,
  ContactTopic.advice => SolarIconsBold.chatRoundLike,
  ContactTopic.payment => SolarIconsBold.walletMoney,
  ContactTopic.document => SolarIconsBold.documentText,
  ContactTopic.suggestion => SolarIconsBold.lightbulb,
  ContactTopic.problem => SolarIconsBold.dangerTriangle,
  ContactTopic.thanks => SolarIconsBold.heart,
  ContactTopic.extraLesson => SolarIconsBold.bookBookmark,
  ContactTopic.other => SolarIconsBold.pen,
};

Color topicColor(ContactTopic topic) => switch (topic) {
  ContactTopic.absence => SK.amber,
  ContactTopic.earlyPickup => const Color(0xFFFF8A4C),
  ContactTopic.homework => SK.sky,
  ContactTopic.progress => SK.green,
  ContactTopic.meeting => const Color(0xFF4F86FF),
  ContactTopic.behavior => SK.teal,
  ContactTopic.wellbeing => SK.green,
  ContactTopic.bullying => SK.red,
  ContactTopic.advice => SK.teal,
  ContactTopic.payment => SK.teal,
  ContactTopic.document => SK.sky,
  ContactTopic.suggestion => SK.amber,
  ContactTopic.problem => SK.red,
  ContactTopic.thanks => const Color(0xFFFF6B9A),
  ContactTopic.extraLesson => SK.sky,
  ContactTopic.other => SK.blue,
};

/// Shablondagi `{student}` uchun ism: "Karimova Aziza" → "Aziza"
/// (ikki so'zdan ko'p bo'lsa ham ikkinchisi — familiyadan keyingi ism).
String studentFirstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.length >= 2 ? parts[1] : fullName.trim();
}
