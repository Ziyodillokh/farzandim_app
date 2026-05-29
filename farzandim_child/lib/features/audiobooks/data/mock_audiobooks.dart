// ─────────────────────────────────────────────────────────────────────
// MockAudiobooks — 8 ta mock audiokitob
// ─────────────────────────────────────────────────────────────────────
//
// audioUrl'lar SoundHelix ochiq sample'larida — kelajakda admin panel
// orqali Firestore'ga joylanadigan real audiokitoblar bilan
// almashtiriladi.

import 'package:farzandim_child/core/theme/app_colors.dart';

import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';

class MockAudiobooks {
  MockAudiobooks._();

  static const String _baseUrl =
      'https://www.soundhelix.com/examples/mp3';

  static final List<AudiobookModel> all = [
    const AudiobookModel(
      id: '1',
      title: 'Oltin baliq haqida ertak',
      author: 'A.Pushkin',
      description: 'Mashhur ertak — keksa kishi va oltin baliq',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-1.mp3',
      durationSeconds: 372,
      duration: '6:12',
      category: 'Ertak',
      hashtags: ['#ertak', '#klassika'],
      listenCount: 5430,
      coverColor: AppColors.catPinkRose,
    ),
    const AudiobookModel(
      id: '2',
      title: 'Layli va Majnun',
      author: 'Alisher Navoiy',
      description: 'Sevgi haqidagi mashhur doston',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-2.mp3',
      durationSeconds: 425,
      duration: '7:05',
      category: 'Doston',
      hashtags: ['#doston', '#navoiy'],
      listenCount: 3210,
      coverColor: AppColors.catLavenderDark,
    ),
    const AudiobookModel(
      id: '3',
      title: 'Sariqdevni minib',
      author: "Tog'ay Murod",
      description: 'Bolalar uchun qiziqarli hikoya',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-3.mp3',
      durationSeconds: 524,
      duration: '8:44',
      category: 'Hikoya',
      hashtags: ['#hikoya', '#bolalar'],
      listenCount: 1890,
      coverColor: AppColors.catMint,
    ),
    const AudiobookModel(
      id: '4',
      title: 'Quyon va toshbaqa',
      author: 'Xalq ertagi',
      description: 'Mehnat va sabr haqidagi ertak',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-4.mp3',
      durationSeconds: 295,
      duration: '4:55',
      category: 'Ertak',
      hashtags: ['#ertak', '#axloqiy'],
      listenCount: 4720,
      coverColor: AppColors.catOrangeWarm,
    ),
    const AudiobookModel(
      id: '5',
      title: 'Kichik shahzoda',
      author: 'A. de Saint-Exupéry',
      description: 'Falsafiy ertak — bola va astronavt',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-5.mp3',
      durationSeconds: 612,
      duration: '10:12',
      category: 'Roman',
      hashtags: ['#klassika', '#falsafa'],
      listenCount: 6890,
      coverColor: AppColors.catLavender,
    ),
    const AudiobookModel(
      id: '6',
      title: 'Astronomik kashfiyotlar',
      author: "Ilmiy bo'lim",
      description: 'Koinot va sayyoralar haqida',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-6.mp3',
      durationSeconds: 480,
      duration: '8:00',
      category: 'Ilmiy',
      hashtags: ['#ilmiy', '#koinot'],
      listenCount: 1230,
      coverColor: AppColors.catGreen,
    ),
    const AudiobookModel(
      id: '7',
      title: 'Aqlli Qulqush',
      author: 'Xalq ertagi',
      description: 'Aqlli qush haqidagi qiziqarli ertak',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-7.mp3',
      durationSeconds: 340,
      duration: '5:40',
      category: 'Ertak',
      hashtags: ['#ertak', '#bolalar'],
      listenCount: 2890,
      coverColor: AppColors.catOrangeLight,
    ),
    const AudiobookModel(
      id: '8',
      title: 'Sherlok Xolms',
      author: 'A. Conan Doyle',
      description: 'Detektiv hikoyasi',
      coverUrl: '',
      audioUrl: '$_baseUrl/SoundHelix-Song-8.mp3',
      durationSeconds: 720,
      duration: '12:00',
      category: 'Detektiv',
      hashtags: ['#detektiv', '#hikoya'],
      listenCount: 3450,
      coverColor: AppColors.catPinkVibrant,
    ),
  ];
}
