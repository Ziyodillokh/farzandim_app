// ─────────────────────────────────────────────────────────────────────
// CareRequestScreen — psixologga murojaat (`/school/request/new`)
// ─────────────────────────────────────────────────────────────────────
//
// Bola mavzuni tanlaydi (7 ta), xabarini yozadi (1000 belgigacha) va
// kerak bo'lsa "Shoshilinch"ni yoqadi. Xabarni faqat maktab psixologi
// o'qiydi. Kuniga 5 tadan ortiq murojaat — 429 (tushunarli xabar, matn
// saqlanib qoladi). Hozir xavf bo'lsa — SOS (Chatlar) yoki 112. Matn faqat
// xotirada: yuborilgach o'chiriladi; chiqishda tasdiq so'raladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/school_style.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/care_request_fields.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_dialogs.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_result_page.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// SOS xabar yuboriladigan sahifa (Chatlar).
const _sosRoute = '/chats';

class CareRequestScreen extends ConsumerStatefulWidget {
  const CareRequestScreen({super.key});

  @override
  ConsumerState<CareRequestScreen> createState() => _CareRequestScreenState();
}

class _CareRequestScreenState extends ConsumerState<CareRequestScreen> {
  final _message = TextEditingController();
  CareTopic? _topic;
  bool _isUrgent = false;
  bool _sending = false;
  bool _isSent = false;
  SchoolErrorCode? _error;

  String get _text => _message.text.trim();

  bool get _canSend =>
      _topic != null &&
      _text.isNotEmpty &&
      _text.length <= kCareMessageMaxLength;

  /// Yuborilmagan matn bor (chiqishda tasdiq so'raladi).
  bool get _hasDraft => !_isSent && _text.isNotEmpty;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _selectTopic(CareTopic topic) {
    HapticFeedback.selectionClick();
    setState(() {
      _topic = topic;
      _error = null;
    });
  }

  Future<void> _send() async {
    final topic = _topic;
    if (topic == null || !_canSend || _sending) return;
    FocusScope.of(context).unfocus();
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await container
          .read(schoolRepositoryProvider)
          .createCareRequest(
            topic: topic,
            message: _text,
            urgency: _isUrgent ? CareUrgency.urgent : CareUrgency.normal,
          );
      container.invalidate(careRequestsProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Matn xotirada qolmaydi.
      _message.clear();
      setState(() {
        _sending = false;
        _isSent = true;
      });
    } on SchoolException catch (e) {
      _fail(e.code);
    } catch (e, stack) {
      debugPrint('[school] murojaat: $e\n$stack');
      _fail(SchoolErrorCode.unknown);
    }
  }

  void _fail(SchoolErrorCode code) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _sending = false;
      _error = code;
    });
  }

  Future<void> _close() async {
    // Yuborilmoqda — natijani kutamiz (bir necha soniya).
    if (_sending) return;
    if (_hasDraft &&
        !await confirmSchoolLeave(
          context,
          titleKey: 'school.leave.requestTitle',
          bodyKey: 'school.leave.requestBody',
        )) {
      return;
    }
    if (mounted) closeSchoolPage(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSent) {
      return SchoolResultPage(
        key: const ValueKey('care-request-sent'),
        icon: SolarIconsBold.plain,
        color: HomeColors.green,
        title: 'school.requests.sentTitle'.tr(),
        actions: [
          SetupButton(
            label: 'school.requests.done'.tr(),
            onTap: () => closeSchoolPage(context),
          ),
        ],
        children: [SchoolResultNote('school.requests.sentBody'.tr())],
      );
    }
    return PopScope(
      canPop: !_hasDraft,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: HomeColors.bg,
        body: DesignScale(
          child: Builder(
            builder: (context) => Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      growthTopInset(context),
                      16,
                      24,
                    ),
                    children: [
                      InnerPageHeader(
                        title: 'school.requests.newTitle'.tr(),
                        fallbackRoute: SchoolRoutes.hub,
                        onBack: _close,
                      ),
                      const SizedBox(height: 16),
                      SchoolNote(
                        icon: SolarIconsOutline.lockKeyhole,
                        color: SchoolColors.accent,
                        iconColor: SchoolColors.accent,
                        text: 'school.requests.intro'.tr(),
                      ),
                      const SizedBox(height: 18),
                      CareFieldLabel('school.requests.topicLabel'.tr()),
                      const SizedBox(height: 10),
                      CareTopicChips(
                        selected: _topic,
                        onSelected: _selectTopic,
                      ),
                      const SizedBox(height: 18),
                      CareFieldLabel('school.requests.messageLabel'.tr()),
                      const SizedBox(height: 10),
                      CareMessageField(
                        controller: _message,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 10),
                      CareUrgentToggle(
                        value: _isUrgent,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _isUrgent = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      CareSosNote(onSos: () => context.push(_sosRoute)),
                    ],
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final error = _error;
    final note = error != null
        ? (error == SchoolErrorCode.tooManyRequests
                  ? 'school.requests.limitReached'
                  : error.messageKey)
              .tr()
        : (_canSend ? null : 'school.requests.required'.tr());
    return SchoolBottomBar(
      children: [
        if (note != null) ...[
          Text(
            note,
            textAlign: TextAlign.center,
            style: homeText(
              12.5,
              color: error != null ? HomeColors.orange : HomeColors.textDim,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SetupButton(
          label: 'school.requests.send'.tr(),
          busy: _sending,
          onTap: _canSend ? _send : null,
        ),
      ],
    );
  }
}
