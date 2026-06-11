// ─────────────────────────────────────────────────────────────────────
// MockVideos — 8 ta mock video ro'yxati
// ─────────────────────────────────────────────────────────────────────
//
// 6 ta klassik (>90 sek) + 2 ta reels (≤90 sek). videoUrl'lar Google'ning
// ochiq sample CDN'idan (commondatastorage.googleapis.com/gtv-videos-bucket)
// — global, ishonchli va UZ tarmoqlaridan ham ochiladi. Kelajakda admin
// panel orqali Firestore'ga joylanadigan real videolar bilan almashtiriladi.
//
// thumbnailUrl — Unsplash bepul rasmlardan, har mavzuga mos qilib
// tanlangan. Real videolar yuklangach admin tomondan o'zgartiriladi.
// `&w=600&auto=format&fit=crop` parametrlari yuklanish tezligi uchun.

import 'package:farzandim_child/core/theme/app_colors.dart';

import 'package:farzandim_child/features/videos/data/models/video_model.dart';

class MockVideos {
  MockVideos._();

  // Google ochiq sample CDN — uzun klassik videolar.
  static const String _cdn =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample';
  static const String _sintel = '$_cdn/Sintel.mp4';
  static const String _bunny = '$_cdn/BigBuckBunny.mp4';
  static const String _movie300 = '$_cdn/ElephantsDream.mp4';

  // Qisqa klassik/reels samplelar (~15-60s) — bir xil ishonchli CDN.
  static const String _bunnyReel = '$_cdn/ForBiggerBlazes.mp4';
  static const String _jellyfishReel = '$_cdn/ForBiggerJoyrides.mp4';

  static final List<VideoModel> all = [
    const VideoModel(
      id: '1',
      title: 'Kasrlar va ulardagi amallar',
      description: "Boshlang'ich sinflar uchun matematika darsi",
      thumbnailUrl:
          'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=600&auto=format&fit=crop',
      duration: '12:34',
      durationSeconds: 754,
      videoUrl: _sintel,
      category: 'Matematika',
      soha: 'Aniq fanlar',
      yonalish: "Ta'lim",
      yoshGuruhi: '10-12',
      hashtags: ['#matematika', '#kasr'],
      views: 1250,
      thumbnailColor: AppColors.catLavenderDark,
    ),
    const VideoModel(
      id: '2',
      title: 'Quyosh tizimi sayyoralari',
      description: 'Astronomiya bilan tanishuv',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1614728263952-84ea256f9679?w=600&auto=format&fit=crop',
      duration: '8:45',
      durationSeconds: 525,
      videoUrl: _bunny,
      category: 'Astronomiya',
      soha: 'Tabiiy fanlar',
      yonalish: 'Hujjatli',
      yoshGuruhi: '6-9',
      hashtags: ['#astronomiya', '#sayyora'],
      views: 3420,
      thumbnailColor: AppColors.catPinkRose,
    ),
    const VideoModel(
      id: '3',
      title: 'Ingliz tili - Family',
      description: "Oila a'zolari ingliz tilida",
      thumbnailUrl:
          'https://images.unsplash.com/photo-1529390079861-591de354faf5?w=600&auto=format&fit=crop',
      duration: '6:12',
      durationSeconds: 372,
      videoUrl: _movie300,
      category: 'Ingliz tili',
      soha: 'Til',
      yonalish: "Ta'lim",
      yoshGuruhi: '6-9',
      hashtags: ['#ingliz', '#oila'],
      views: 890,
      thumbnailColor: AppColors.catMint,
    ),
    const VideoModel(
      id: '4',
      title: 'Suvning aylanishi',
      description: 'Tabiat hodisalari - suv aylanishi',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1501594907352-04cda38ebc29?w=600&auto=format&fit=crop',
      duration: '10:20',
      durationSeconds: 620,
      videoUrl: _sintel,
      category: 'Geografiya',
      soha: 'Tabiiy fanlar',
      yonalish: "Ta'lim",
      yoshGuruhi: '10-12',
      hashtags: ['#tabiat', '#suv'],
      views: 2100,
      thumbnailColor: AppColors.catOrangeWarm,
    ),
    const VideoModel(
      id: '5',
      title: 'Multfilm - Bola va dengiz',
      description: "Qiziqarli ta'limiy multfilm",
      thumbnailUrl:
          'https://images.unsplash.com/photo-1500964757637-c85e8a162699?w=600&auto=format&fit=crop',
      duration: '15:00',
      durationSeconds: 900,
      videoUrl: _bunny,
      category: 'Adabiyot',
      soha: "San'at",
      yonalish: 'Multfilm',
      yoshGuruhi: '3-5',
      hashtags: ['#multfilm', '#bolalar'],
      views: 5670,
      thumbnailColor: AppColors.catPinkVibrant,
    ),
    const VideoModel(
      id: '6',
      title: 'Futbol tarixi',
      description: "Futbolning paydo bo'lishi",
      thumbnailUrl:
          'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?w=600&auto=format&fit=crop',
      duration: '18:30',
      durationSeconds: 1110,
      videoUrl: _movie300,
      category: 'Tarix',
      soha: 'Sport',
      yonalish: 'Sport',
      yoshGuruhi: '13-15',
      hashtags: ['#futbol', '#sport'],
      views: 1890,
      thumbnailColor: AppColors.catLavender,
    ),
    // ─── REELS (≤90 sek) ─────────────────────────────────────────
    const VideoModel(
      id: '7',
      title: 'Kimyo - Suv molekulasi',
      description: 'H2O strukturasi va xususiyatlari',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1554475901-4538ddfbccc2?w=600&auto=format&fit=crop',
      duration: '1:14',
      durationSeconds: 74,
      videoUrl: _bunnyReel,
      category: 'Kimyo',
      soha: 'Tabiiy fanlar',
      yonalish: "Ta'lim",
      yoshGuruhi: '13-15',
      hashtags: ['#kimyo', '#molekula'],
      views: 760,
      thumbnailColor: AppColors.catGreen,
    ),
    const VideoModel(
      id: '8',
      title: 'Musiqa - Maqom',
      description: "O'zbek mumtoz musiqasi",
      thumbnailUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop',
      duration: '0:45',
      durationSeconds: 45,
      videoUrl: _jellyfishReel,
      category: 'Musiqa',
      soha: "San'at",
      yonalish: 'Musiqa',
      yoshGuruhi: '16+',
      hashtags: ['#musiqa', '#maqom'],
      views: 1340,
      thumbnailColor: AppColors.catOrangeLight,
    ),
  ];
}
