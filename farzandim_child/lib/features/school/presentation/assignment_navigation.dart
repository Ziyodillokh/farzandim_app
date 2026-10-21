// Maktab topshirig'ini ochish: test — shu fanning kunlik testi (profil
// yo'q yoki fan sinfda o'qitilmasa test sahifasi o'zi tushuntiradi),
// audiokitob — kitob sahifasi (alohida endpoint yo'q: kutubxona ro'yxatidan
// topiladi; topilmasa — audiokitoblar ro'yxati), video — videolar ro'yxati.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_series.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/assignment_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AssignmentMaterialRoutes {
  static const audiobookDetail = '/audiobook-detail';
  static const audiobooks = '/audiobooks';
  static const videos = '/videos';
}

/// [audiobookId] qismi bo'lgan kitob (barcha qismlari bilan). Ro'yxat
/// yuklanmasa yoki kitob unda bo'lmasa — `null`.
Future<AudiobookSeries?> findSchoolAudiobook(
  WidgetRef ref,
  String audiobookId,
) async {
  try {
    final books = await ref.read(backendAudiobooksProvider.future);
    return seriesContaining(books, audiobookId);
  } catch (e) {
    // Tarmoq yoki buzilgan javob — bola audiokitoblar ro'yxatiga o'tadi
    // (u yerda yuklash xatosi va "qayta urinish" bor).
    debugPrint('[school] audiokitoblar ro\'yxati yuklanmadi: $e');
    return null;
  }
}

/// Topshiriq materialini ochadi (ochiladigan joy bo'lmasa — hech narsa).
Future<void> openSchoolAssignment(
  BuildContext context,
  WidgetRef ref,
  SchoolAssignment assignment,
) async {
  switch (assignmentTargetOf(assignment)) {
    case AssignmentOpensQuiz(:final subject):
      openSubjectQuiz(context, subject);
    case AssignmentOpensAudiobook(:final audiobookId):
      await _openAudiobook(context, ref, audiobookId);
    case AssignmentOpensVideos():
      HapticFeedback.selectionClick();
      context.push(AssignmentMaterialRoutes.videos);
    case AssignmentOpensNothing():
      return;
  }
}

Future<void> _openAudiobook(
  BuildContext context,
  WidgetRef ref,
  String? audiobookId,
) async {
  HapticFeedback.selectionClick();
  final series = audiobookId == null
      ? null
      : await findSchoolAudiobook(ref, audiobookId);
  if (!context.mounted) return;
  if (series != null) {
    context.push(AssignmentMaterialRoutes.audiobookDetail, extra: series);
    return;
  }
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('school.assignments.bookNotFound'.tr())),
    );
  context.push(AssignmentMaterialRoutes.audiobooks);
}
