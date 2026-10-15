// ─────────────────────────────────────────────────────────────────────
// Dizayn QA — bosh sahifani maket o'lchamida PNG'ga chizish
// ─────────────────────────────────────────────────────────────────────
//
// Maket bilan piksel-piksel solishtirish uchun (CI'da ISHLAMAYDI —
// `test/` emas, `tool/` ichida). iPhone 15 Pro: 393×852 pt.
//
//   flutter test tool/screenshots/home_screenshot_test.dart \
//     --dart-define=SHOT_OUT=/tmp/home.png \
//     --dart-define=SHOT_IMAGES=/papka/rasmlar   # ixtiyoriy: kutubxona rasmlari
//     --dart-define=SHOT_SCALE=2.1705            # ixtiyoriy: piksel zichligi
//     --dart-define=SHOT_LOCALE=uz               # ixtiyoriy: uz | ru | en
//     --dart-define=SHOT_WIDTH=393 --dart-define=SHOT_HEIGHT=852
//     --dart-define=SHOT_TEXT_SCALE=1.0          # ixtiyoriy: shrift masshtabi
//     --dart-define=SHOT_PAGE=home               # home | tests
//
// Ma'lumotlar namunaviy (provider override'lar), tarmoq yo'q.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/data/repositories/contests_backend_repository.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_feed.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/tests/presentation/screens/tests_screen.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/video_engagement_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = String.fromEnvironment('SHOT_OUT', defaultValue: 'build/home.png');
const _imagesDir = String.fromEnvironment('SHOT_IMAGES');
const _scale = String.fromEnvironment('SHOT_SCALE', defaultValue: '2.1705');
const _locale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'uz');
const _width = String.fromEnvironment('SHOT_WIDTH', defaultValue: '393');
const _height = String.fromEnvironment('SHOT_HEIGHT', defaultValue: '852');
const _textScale = String.fromEnvironment('SHOT_TEXT_SCALE', defaultValue: '1');
const _page = String.fromEnvironment('SHOT_PAGE', defaultValue: 'home');

const _safeTop = 59.0;
const _safeBottom = 34.0;

void main() {
  testWidgets('bosh sahifa skrinshoti', (tester) async {
    final dpr = double.parse(_scale);
    final logical = Size(double.parse(_width), double.parse(_height));
    tester.platformDispatcher.textScaleFactorTestValue = double.parse(
      _textScale,
    );
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view
      ..physicalSize = logical * dpr
      ..devicePixelRatio = dpr
      ..padding = FakeViewPadding(
        top: _safeTop * dpr,
        bottom: _safeBottom * dpr,
      );
    addTearDown(tester.view.reset);

    // Harness `tool/` ichida (CI'da ishlamaydi), lekin flutter_test bilan
    // ishlaydi — test-only API bu yerda maqsadli.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      await _loadManifestFonts();
      await _preloadGoogleFonts();
      await EasyLocalization.ensureInitialized();
    });

    final boundary = GlobalKey();
    await HttpOverrides.runZoned(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(RepaintBoundary(key: boundary, child: _app()));
        // Tarjimalar, shriftlar va rasmlar asinxron yuklanadi.
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await tester.pump();
        }
        await GoogleFonts.pendingFonts();
        await _precacheImages(tester);
      });
      await tester.pump(const Duration(milliseconds: 300));

      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: dpr);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(_out)..createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }, createHttpClient: (_) => _FileHttpClient());
    expect(File(_out).existsSync(), isTrue);
  });
}

Widget _app() {
  final router = GoRouter(
    initialLocation: _page == 'tests' ? '/contests' : '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => HomeScaffold(
          onRefresh: () async {},
          navigation: const ChildBottomNavigation(showMiniPlayer: false),
        ),
      ),
      GoRoute(
        path: '/contests',
        builder: (_, __) => const TestsScreen(
          navigation: ChildBottomNavigation(showMiniPlayer: false),
        ),
      ),
    ],
  );
  return EasyLocalization(
    supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('uz'),
    startLocale: const Locale(_locale),
    child: ProviderScope(
      overrides: [
        backendGamificationProvider.overrideWith(
          (ref) => Stream.value(
            const BackendGamification(
              xp: 1200,
              don: 480,
              streak: 7,
              level: 3,
              status: 'active',
            ),
          ),
        ),
        gamificationProfileProvider.overrideWith((ref) => const Stream.empty()),
        unreadNotificationsCountProvider.overrideWithValue(
          const AsyncValue.data(0),
        ),
        topVideosProvider.overrideWithValue(_videos),
        newestAudiobooksProvider.overrideWithValue(_books),
        favoriteVideoIdsProvider.overrideWith(_OfflineFavorites.new),
        backendContestsProvider.overrideWith((ref) async => _contests()),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          routerConfig: router,
        ),
      ),
    ),
  );
}

VideoModel _video(String id, String title, String category, String image) =>
    VideoModel(
      id: id,
      title: title,
      description: '',
      thumbnailUrl: 'https://shot.local/$image.png',
      duration: '10:00',
      durationSeconds: 600,
      videoUrl: '',
      category: category,
      soha: '',
      yonalish: '',
      yoshGuruhi: '',
      hashtags: const [],
      views: 1000,
      thumbnailColor: const Color(0xFF173654),
      xpReward: 50,
    );

final _videos = [
  _video('v1', 'Muvaffaqiyat psixologiyasi', 'Abdulla Oripov', 'mountain'),
  _video('v2', 'Dunyo tarixi 10 daqiqada', 'Parvoz Growth', 'earth'),
];

const _books = [
  AudiobookModel(
    id: 'a1',
    title: 'Buyuk insonlar hayoti',
    author: 'Abdulla Oripov',
    description: '',
    coverUrl: 'https://shot.local/city.png',
    audioUrl: '',
    durationSeconds: 1800,
    duration: '30:00',
    category: '',
    hashtags: [],
    listenCount: 10,
    coverColor: Color(0xFF3A2A22),
  ),
];

/// Maketdagi 6 fan: har birida 30 ta test, faollarining bonusi jami 250 DON.
ContestBundle _contests() {
  const subjects = [
    'Ilmiy-ommabop',
    'Matematika',
    'Ingliz tili',
    'Tarix',
    'Geografiya',
    'Biologiya',
  ];
  ContestModel test(String soha, int i, {required bool active}) => ContestModel(
    id: '$soha-$i',
    title: '$soha #$i',
    description: '',
    soha: soha,
    ishtirokchilarSoni: 10,
    deadline: DateTime(2026, 12, 31),
    isActive: active,
    placeholderColor: const Color(0xFF173654),
    placeholderIcon: Icons.quiz_outlined,
    bonus: 25,
    savollarSoni: 10,
    vaqtChegarasiDaq: 15,
  );
  return ContestBundle(
    active: [
      for (final s in subjects)
        for (var i = 0; i < 10; i++) test(s, i, active: true),
    ],
    finished: [
      for (final s in subjects)
        for (var i = 10; i < 30; i++) test(s, i, active: false),
    ],
  );
}

/// Sevimlilar — backend so'rovisiz (test muhiti).
class _OfflineFavorites extends FavoriteVideoIdsNotifier {
  @override
  Set<String> build() => const {};
}

/// FontManifest'dagi barcha oilalar (Material, Solar ikonlari) — testda
/// standart holatda yuklanmaydi.
Future<void> _loadManifestFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Bosh sahifadagi barcha shrift og'irliklari — birinchi kadrdan oldin
/// (aks holda test shriftida o'lchanib, qatorlar sig'may qoladi).
Future<void> _preloadGoogleFonts() async {
  for (final w in [FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.montserrat(fontWeight: w);
  }
  for (final w in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.plusJakartaSans(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}

Future<void> _precacheImages(WidgetTester tester) async {
  if (_page == 'tests') {
    await precacheImage(
      const AssetImage('assets/illustrations/tests_hero.png'),
      tester.element(find.byType(TestsScreen)),
    );
    return;
  }
  final context = tester.element(find.byType(HomeFeed));
  for (final url in [
    ..._videos.map((v) => v.thumbnailUrl),
    ..._books.map((b) => b.coverUrl),
  ]) {
    await precacheImage(NetworkImage(url), context);
  }
}

// ─── Tarmoq o'rniga lokal fayllar (SHOT_IMAGES/<nom>.png) ────────────

class _FileHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FileRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FileRequest implements HttpClientRequest {
  _FileRequest(this.url);

  final Uri url;

  @override
  Future<HttpClientResponse> close() async {
    final file = File('$_imagesDir/${url.pathSegments.last}');
    final bytes = _imagesDir.isNotEmpty && file.existsSync()
        ? file.readAsBytesSync()
        : _transparentPng;
    return _FileResponse(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FileResponse extends Stream<List<int>> implements HttpClientResponse {
  _FileResponse(this._bytes);

  final List<int> _bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 1×1 shaffof PNG (rasm topilmasa).
const _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
