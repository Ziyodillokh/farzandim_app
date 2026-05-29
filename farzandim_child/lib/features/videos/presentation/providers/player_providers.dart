// ─────────────────────────────────────────────────────────────────────
// player_providers — Riverpod state
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/videos/data/models/player_settings.dart';

final playerSettingsProvider =
    StateProvider<PlayerSettings>((ref) => const PlayerSettings());
