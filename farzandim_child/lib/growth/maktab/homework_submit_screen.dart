// M08 · Javob yuborish: yozma uy vazifasini rasm(lar) va ixtiyoriy izoh bilan
// topshirish. Holatlar halol: «Yuborilmoqda…» → «Yuborildi · 15:20» faqat
// server javobidan keyin; xato bo'lsa — aniq xabar va qayta urinish (bir xil
// requestId bilan — server takroriy yozuv ochmaydi).

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/maktab/school_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Rasm sifati va o'lchami (8 MB chegarasidan ancha past bo'lsin).
const _maxPhotoSide = 2000.0;
const _photoQuality = 82;

enum _Phase { editing, sending, sent, failed }

class HomeworkSubmitScreen extends ConsumerStatefulWidget {
  const HomeworkSubmitScreen({super.key, required this.taskId, this.picker});

  final String taskId;

  /// Testlarda almashtiriladi.
  final ImagePicker? picker;

  @override
  ConsumerState<HomeworkSubmitScreen> createState() =>
      _HomeworkSubmitScreenState();
}

class _HomeworkSubmitScreenState extends ConsumerState<HomeworkSubmitScreen> {
  final _photos = <String>[];
  final _comment = TextEditingController();
  late final String _requestId = newRequestId();
  var _phase = _Phase.editing;
  String? _error;
  DateTime? _sentAt;

  ImagePicker get _picker => widget.picker ?? ImagePicker();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _add(ImageSource source) async {
    if (_photos.length >= kHomeworkMaxPhotos) return;
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _maxPhotoSide,
      maxHeight: _maxPhotoSide,
      imageQuality: _photoQuality,
    );
    if (file == null || !mounted) return;
    final size = await File(file.path).length();
    if (size > kHomeworkMaxPhotoBytes) {
      setState(() => _error = 'g5.school.submit.tooBig'.tr());
      return;
    }
    setState(() {
      _photos.add(file.path);
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_photos.isEmpty) {
      setState(() => _error = 'g5.school.submit.needPhoto'.tr());
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    try {
      final submission = await ref
          .read(schoolV5RepositoryProvider)
          .submitHomework(
            assignmentId: widget.taskId,
            photoPaths: List.unmodifiable(_photos),
            comment: _comment.text,
            requestId: _requestId,
          );
      ref.invalidate(schoolAssignmentsProvider);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.sent;
        _sentAt = submission.submittedAt ?? DateTime.now();
      });
    } on SchoolException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = switch (e.code) {
          SchoolErrorCode.validation => 'g5.school.submit.tooBig'.tr(),
          SchoolErrorCode.alreadySubmitted =>
            'g5.school.submit.alreadyAccepted'.tr(),
          SchoolErrorCode.unavailable => 'g5.school.submit.closed'.tr(),
          _ => 'g5.school.submit.failed'.tr(),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task =
        (ref.watch(schoolAssignmentsProvider).valueOrNull ??
                const <SchoolAssignment>[])
            .where((t) => t.id == widget.taskId)
            .firstOrNull;
    final sending = _phase == _Phase.sending;
    final sent = _phase == _Phase.sent;
    return Scaffold(
      backgroundColor: GColors.bg,
      body: GScreen(
        theme: GBgTheme.teal,
        top: GTopBar(
          leading: GTopBar.back(
            label: 'g5.common.back'.tr(),
            onPressed: () => context.pop(),
          ),
          title: 'g5.school.submit.title'.tr(),
          subtitle: task == null ? null : taskTitle(task),
        ),
        dock: sent
            ? GButton(
                label: 'g5.school.submit.back'.tr(),
                kind: GButtonKind.ghost,
                onPressed: () => context.pop(),
              )
            : GButton(
                label:
                    (sending
                            ? 'g5.school.submit.sending'
                            : 'g5.school.submit.send')
                        .tr(),
                loading: sending,
                icon: GIcons.paperPlaneTilt,
                onPressed: sending ? null : _send,
              ),
        children: [
          if (task != null)
            GGlass(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  taskTile(task),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(taskTitle(task), style: GText.itemTitle),
                        const SizedBox(height: 2),
                        Text(
                          [
                            taskKindLine(task),
                            if (task.teacherName != null) task.teacherName!,
                          ].join(' · '),
                          style: GText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (sent)
            GNote(
              text: 'g5.school.submit.sent'.tr(
                namedArgs: {'time': _clock(_sentAt!)},
              ),
              kind: GNoteKind.ok,
              icon: GIcons.checkCircle,
            )
          else ...[
            _PhotoGrid(
              photos: _photos,
              enabled: !sending,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
              onAddCamera: _photos.length >= kHomeworkMaxPhotos
                  ? null
                  : () => _add(ImageSource.camera),
              onAddGallery: _photos.length >= kHomeworkMaxPhotos
                  ? null
                  : () => _add(ImageSource.gallery),
            ),
            Text(
              'g5.school.submit.limit'.tr(
                namedArgs: {'count': '$kHomeworkMaxPhotos'},
              ),
              style: GText.caption,
            ),
            GTextField(
              label: 'g5.school.submit.comment'.tr(),
              controller: _comment,
              multiline: true,
              maxLength: 1000,
              enabled: !sending,
            ),
            if (_error != null)
              GNote(
                text: _error!,
                kind: GNoteKind.warn,
                icon: GIcons.warningCircle,
              ),
            GNote(text: 'g5.school.submit.honest'.tr(), kind: GNoteKind.plain),
          ],
        ],
      ),
    );
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.enabled,
    required this.onRemove,
    required this.onAddCamera,
    required this.onAddGallery,
  });

  final List<String> photos;
  final bool enabled;
  final ValueChanged<int> onRemove;
  final VoidCallback? onAddCamera;
  final VoidCallback? onAddGallery;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final size = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < photos.length; i++)
              SizedBox(
                width: size,
                height: size * 1.25,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(photos[i]),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: GChip(
                        label: 'g5.school.submit.page'.tr(
                          namedArgs: {'n': '${i + 1}'},
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GIconButton(
                        icon: GIcons.trash,
                        label: 'g5.school.submit.remove'.tr(
                          namedArgs: {'n': '${i + 1}'},
                        ),
                        onPressed: enabled ? () => onRemove(i) : null,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            if (onAddCamera != null && enabled)
              _AddTile(
                size: size,
                icon: GIcons.camera,
                label: 'g5.school.submit.camera'.tr(),
                onTap: onAddCamera!,
              ),
            if (onAddGallery != null && enabled)
              _AddTile(
                size: size,
                icon: GIcons.images,
                label: 'g5.school.submit.gallery'.tr(),
                onTap: onAddGallery!,
              ),
          ],
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double size;
  final GIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GPressable(
      onTap: onTap,
      semanticLabel: '${'g5.school.submit.addPhoto'.tr()}: $label',
      child: Container(
        width: size,
        height: size * 1.25,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: GColors.fieldFill,
          border: Border.all(color: GColors.fieldBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GIcon(icon, size: 26, color: GColors.link),
            const SizedBox(height: 8),
            Text(
              label,
              style: GText.onest(
                13,
                weight: FontWeight.w600,
                color: GColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
