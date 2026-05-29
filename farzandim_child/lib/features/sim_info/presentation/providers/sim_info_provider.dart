import 'package:farzandim_child/features/sim_info/data/services/sim_info_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `SimInfoService` provider'i — testlarda override qilish uchun.
final simInfoServiceProvider = Provider<SimInfoService>(
  (ref) => SimInfoService(),
);
