import 'package:flutter_bloc/flutter_bloc.dart';

/// Desktop/tablet: tor sidebar (faqat ikonlar) ↔ to‘liq.
class SidebarRailCubit extends Cubit<bool> {
  SidebarRailCubit() : super(false);

  void toggle() => emit(!state);
}
