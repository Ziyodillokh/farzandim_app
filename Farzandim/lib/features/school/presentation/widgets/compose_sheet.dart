// ─────────────────────────────────────────────────────────────────────
// ComposeSheet — maktab xodimiga xabar (shablon matni tahrirlanadi)
// ─────────────────────────────────────────────────────────────────────
//
// Shablon (mavzu) tanlangach matn tayyor bo'ladi; ota-ona uni o'ziga
// moslab yuboradi. Yuborilgach yozishma ochiladi. Psixologga yozishda
// maxfiylik eslatmasi ko'rsatiladi.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/widgets/connect_style.dart';
import 'package:farzandim/features/school/presentation/widgets/school_form_fields.dart';
import 'package:farzandim/features/school/presentation/widgets/school_kit.dart';
import 'package:farzandim/features/school/presentation/widgets/school_sheet.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Shablon matni: `{student}` — o'quvchi ismi.
String templateText(ContactTopic topic, ConnectStudent student) =>
    topic.bodyKey.tr(namedArgs: {'student': studentFirstName(student.name)});

/// Varaqni ochadi; yuborilsa yozishma sahifasiga o'tadi. [prefill] — tayyor
/// matn (masalan, e'lon yoki kelmagan kun haqida); bo'lmasa shablon matni.
Future<void> showComposeSheet(
  BuildContext context, {
  required SchoolContact contact,
  required ConnectStudent student,
  required ContactTopic topic,
  String? prefill,
}) async {
  final thread = await showSchoolSheet<SchoolThread>(
    context,
    builder: (_) => _ComposeSheet(
      contact: contact,
      student: student,
      topic: topic,
      initial: prefill ?? templateText(topic, student),
    ),
  );
  if (thread == null || !context.mounted) return;
  unawaited(context.push(AppRoutes.schoolThreadPath(thread.id)));
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet({
    required this.contact,
    required this.student,
    required this.topic,
    required this.initial,
  });

  final SchoolContact contact;
  final ConnectStudent student;
  final ContactTopic topic;
  final String initial;

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  bool _sending = false;
  String? _error;

  bool get _canSend {
    final text = _text.text.trim();
    return text.isNotEmpty && text.length <= kParentMessageMax;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final thread = await ref
          .read(schoolConnectActionsProvider)
          .start(
            contact: widget.contact,
            studentId: widget.student.id,
            topic: widget.topic,
            body: _text.text,
          );
      if (!mounted) return;
      AppToast.success(context, 'school.connect.sent'.tr());
      Navigator.of(context).pop(thread);
    } on SchoolFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failure.messageKey.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final color = roleColor(contact.role);
    final error = _error;
    return SchoolSheetFrame(
      title: widget.topic.titleKey.tr(),
      subtitle: 'school.connect.composeTo'.tr(
        namedArgs: {
          'name': contact.fullName,
          'role': contact.role.labelKey.tr(),
        },
      ),
      children: [
        Row(
          children: [
            SkIconBubble(icon: topicIcon(widget.topic), color: color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'school.connect.aboutStudent'.tr(
                  namedArgs: {
                    'name': widget.student.name,
                    'className': widget.student.className,
                  },
                ),
                style: skText(13.5, c: SK.dim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (contact.isConfidential) ...[
          SchoolNote(
            icon: SolarIconsBold.lockKeyhole,
            text: 'school.connect.confidential'.tr(),
          ),
          const SizedBox(height: 14),
        ],
        SchoolTextArea(
          label: 'school.connect.composeHint'.tr(),
          hint: 'school.connect.placeholder'.tr(),
          controller: _text,
          maxLength: kParentMessageMax,
          maxLines: 7,
          enabled: !_sending,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          SchoolInlineError(message: error),
        ],
        const SizedBox(height: 18),
        ParvozPrimaryButton(
          label: 'school.connect.send'.tr(),
          onPressed: _send,
          enabled: _canSend,
          loading: _sending,
          showArrow: false,
        ),
        const SizedBox(height: 4),
        SchoolTextButton(
          label: 'common.cancel'.tr(),
          onTap: _sending ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
