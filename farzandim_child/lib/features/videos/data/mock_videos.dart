// ─────────────────────────────────────────────────────────────────────
// MockVideos — 8 ta mock video ro'yxati
// ─────────────────────────────────────────────────────────────────────
//
// 6 ta klassik (>90 sek) + 2 ta reels (≤90 sek). videoUrl'lar
// W3C va test-videos.co.uk ochiq sample videolaridan — kelajakda
// admin panel orqali Firestore'ga joylanadigan real videolar bilan
// almashtiriladi.

import 'package:farzandim_child/core/theme/app_colors.dart';

import 'package:farzandim_child/features/videos/data/models/video_model.dart';

class MockVideos {
  MockVideos._();

  // W3C — uzun sample videolar (~60s trailerlar)
  static const String _sintel =
      'https://media.w3.org/2010/05/sintel/trailer.mp4';
  static const String _bunny =
      'https://media.w3.org/2010/05/bunny/trailer.mp4';
  static const String _movie300 =
      'https://media.w3.org/2010/05/video/movie_300.mp4';

  // test-videos.co.uk — qisqa reels (~10s)
  static const String _bunnyReel =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4';
  static const String _jellyfishReel =
      'https://test-videos.co.uk/vids/jellyfish/mp4/h264/360/Jellyfish_360_10s_1MB.mp4';

  static final List<VideoModel> all = [
    const VideoModel(
      id: '1',
      title: 'Kasrlar va ulardagi amallar',
      description: "Boshlang'ich sinflar uchun matematika darsi",
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
      thumbnailUrl: '',
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
