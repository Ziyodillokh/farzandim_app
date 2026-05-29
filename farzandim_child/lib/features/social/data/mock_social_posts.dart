// ─────────────────────────────────────────────────────────────────────
// MockSocialPosts — 8 ta misol post (development uchun)
// ─────────────────────────────────────────────────────────────────────
//
// Kelajakda Firestore `social_posts` collection'idan keladi.
// Admin panel orqali real kontent yaratuvchilar (ustozlar) post
// qo'shadi. Hozir static.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/social/data/models/social_post.dart';

class MockSocialPosts {
  MockSocialPosts._();

  // Author'lar
  static const _ustozAli = SocialAuthor(
    id: 'ustoz_ali',
    name: 'Ustoz Ali',
    avatarColor: AppColors.catBlue,
    verified: true,
  );
  static const _ustozGulnora = SocialAuthor(
    id: 'ustoz_gulnora',
    name: 'Ustoz Gulnora',
    avatarColor: AppColors.catPinkVibrant,
    verified: true,
  );
  static const _olimMatem = SocialAuthor(
    id: 'olim_matem',
    name: 'Matematika Olimpiadasi',
    avatarColor: AppColors.catViolet,
    verified: true,
  );
  static const _farzandim = SocialAuthor(
    id: 'farzandim_official',
    name: 'Farzandim',
    avatarColor: AppColors.catLimeBright,
    verified: true,
  );
  static const _ilmTV = SocialAuthor(
    id: 'ilm_tv',
    name: 'Ilm TV',
    avatarColor: AppColors.catAmber,
    verified: true,
  );

  static final List<SocialPost> all = [
    SocialPost(
      id: '1',
      author: _ustozAli,
      text:
          "Bugun darsda yangi kashfiyot qildim: matematikada eng katta son haqida bilasizmi? Birgalikda o'rganamiz! 🔢",
      mediaType: SocialMediaType.text,
      tags: const ['#matematika', '#dars'],
      likes: 142,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    SocialPost(
      id: '2',
      author: _olimMatem,
      text:
          "Iste'dod Uchquni olimpiadasi 26-fevralda boshlanadi. Ro'yxatdan o'tib qoyaver! 🏆",
      mediaType: SocialMediaType.image,
      tags: const ['#olimpiada', '#konkurs'],
      likes: 387,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      thumbnailColor: AppColors.catLavender,
    ),
    SocialPost(
      id: '3',
      author: _ustozGulnora,
      text:
          "Ona tili dars: 'osmon' so'zining 5 ta sinonimini topa olasizmi? Komment qiling 📝",
      mediaType: SocialMediaType.text,
      tags: const ['#onatili', '#sinonim'],
      likes: 89,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    SocialPost(
      id: '4',
      author: _ilmTV,
      text:
          "Quyosh tizimi: yangi video chiqdi! Sayyoralarning yashirin sirlari ✨",
      mediaType: SocialMediaType.video,
      tags: const ['#astronomiya', '#video'],
      likes: 521,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      thumbnailColor: AppColors.catPinkRose,
    ),
    SocialPost(
      id: '5',
      author: _farzandim,
      text:
          "Yangi yutuq! 1000 ta bola allaqachon Farzandim'da o'qiyapti 🎉 Siz ham qo'shilasizmi?",
      mediaType: SocialMediaType.text,
      tags: const ['#farzandim', '#yutuq'],
      likes: 1024,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
    ),
    SocialPost(
      id: '6',
      author: _ustozAli,
      text:
          "Bugungi savol: 7 × 8 ni 5 sekundda ayta olasizmi? Komment yozing!",
      mediaType: SocialMediaType.text,
      tags: const ['#matematika', '#viktorina'],
      likes: 246,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    SocialPost(
      id: '7',
      author: _ilmTV,
      text: "Tabiat: bambuk daraxti bir kunda 91 sm o'sadi! 🎋",
      mediaType: SocialMediaType.image,
      tags: const ['#tabiat', '#qiziqarli'],
      likes: 178,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      thumbnailColor: AppColors.catEmeraldLight,
    ),
    SocialPost(
      id: '8',
      author: _ustozGulnora,
      text:
          "Adabiyot: Abdulla Qodiriyning 'Mehrobdan chayon' romaningiz o'qib chiqdingizmi? Sizning fikringiz qanday?",
      mediaType: SocialMediaType.text,
      tags: const ['#adabiyot', '#kitob'],
      likes: 67,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  /// Default follow ro'yxati — bola onboarding'da uch ustozni avtomatik
  /// follow qiladi. Keyinroq o'zgartira oladi.
  static const Set<String> defaultFollowing = {
    'ustoz_ali',
    'farzandim_official',
    'olim_matem',
  };
}
