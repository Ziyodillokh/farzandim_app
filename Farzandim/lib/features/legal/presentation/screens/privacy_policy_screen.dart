import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/legal/data/legal_text.dart';
import 'package:farzandim/features/legal/presentation/widgets/legal_text_scaffold.dart';
import 'package:flutter/material.dart';

/// Maxfiylik siyosati ekrani.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalTextScaffold(
      title: 'legal.privacyPolicyTitle'.tr(),
      sections: LegalText.privacyPolicy,
    );
  }
}
