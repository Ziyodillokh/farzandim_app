// Kutubxona testlari va skrinshotlari uchun soxta ma'lumot, pleyer va maqola manbai.

import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/data/repositories/articles_backend_repository.dart';
import 'package:farzandim_child/features/articles/presentation/providers/articles_providers.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audio_player_state.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audio_player_provider.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

AudiobookModel libBook(String id, String title, {int seconds = 1260}) =>
    AudiobookModel(
      id: id,
      title: title,
      author: 'Muallif',
      description: '',
      coverUrl: '',
      audioUrl: 'https://example.invalid/$id.mp3',
      durationSeconds: seconds,
      duration: '${seconds ~/ 60} daq',
      category: 'Ertak',
      hashtags: const [],
      listenCount: 0,
      coverColor: const Color(0xFF10B981),
    );

final kLibBooks = [
  libBook('b1', 'Oʻrmon sirlari 1'),
  libBook('b2', 'Oʻrmon sirlari 2'),
  libBook('b3', 'Ipak yoʻli'),
];

const kLibVideo = VideoModel(
  id: 'v1',
  title: 'Kasrlarni taqqoslash',
  description: 'Umumiy maxraj yordamida',
  thumbnailUrl: '',
  duration: '8:40',
  durationSeconds: 520,
  videoUrl: 'https://example.invalid/v1.mp4',
  category: 'Matematika',
  soha: '',
  yonalish: '',
  yoshGuruhi: '10-13',
  hashtags: [],
  views: 0,
  thumbnailColor: Color(0xFF4F86FF),
);

const kLibArticle = ArticleModel(
  id: 'a1',
  title: 'Urugʻ qanday unib chiqadi?',
  body:
      'Urugʻ suv va issiqlik bilan uygʻonadi. Avval ildiz, keyin nihol chiqadi.',
  coverUrl: '',
  category: 'Biologiya',
  ageFrom: 10,
  ageTo: 13,
  views: 0,
  coverColor: Color(0xFF14B8A6),
);

class FakeLibBooks extends AudiobooksNotifier {
  @override
  Future<List<AudiobookModel>> build() async => kLibBooks;
}

class FakeLibPlayer extends StateNotifier<AudioPlayerState>
    implements AudioPlayerNotifier {
  FakeLibPlayer() : super(const AudioPlayerState());

  final played = <String>[];

  @override
  Future<void> play(AudiobookModel book) async {
    played.add(book.id);
    state = AudioPlayerState(
      currentBook: book,
      isPlaying: true,
      duration: Duration(seconds: book.durationSeconds),
    );
  }

  @override
  Future<void> pause() async => state = state.copyWith(isPlaying: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLibArticles implements ArticlesBackendRepository {
  final read = <String>[];

  @override
  Future<void> markRead(String id) async => read.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Kutubxona provayderlarini soxtalari bilan almashtiradi.
List<Override> libraryOverrides({
  required FakeLibPlayer player,
  required FakeLibArticles articles,
}) => [
  backendAudiobooksProvider.overrideWith(FakeLibBooks.new),
  effectiveAudiobooksProvider.overrideWithValue(kLibBooks),
  effectiveVideosProvider.overrideWithValue(const [kLibVideo]),
  effectiveArticlesProvider.overrideWithValue(const [kLibArticle]),
  articlesBackendRepositoryProvider.overrideWithValue(articles),
  audioPlayerProvider.overrideWith((ref) => player),
];
