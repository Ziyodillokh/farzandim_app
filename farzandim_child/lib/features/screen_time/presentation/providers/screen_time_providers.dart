import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:farzandim_child/features/screen_time/data/parent_pin_store.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';

final screenTimeChannelProvider = Provider<ScreenTimeChannel>(
  (ref) => const ScreenTimeChannel(),
);

final parentPinStoreProvider = Provider<ParentPinStore>(
  (ref) => ParentPinStore(),
);

/// "Ekran vaqti" ekrani holati (ruxsat, tanlov soni, cheklov faolmi).
final screenTimeStatusProvider = FutureProvider.autoDispose<ScreenTimeStatus>(
  (ref) => ref.watch(screenTimeChannelProvider).status(),
);
