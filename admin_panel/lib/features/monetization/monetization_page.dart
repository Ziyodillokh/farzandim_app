import 'package:flutter/material.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/app_spacing.dart';

class MonetizationPage extends StatelessWidget {
  const MonetizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const AdminPageHeader(title: 'Monetizatsiya', subtitle: 'Tariflar va to\'lovlar'),
        const SizedBox(height: AppSpacing.sm),
        const SectionTitle('Tariflar'),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: const [
            Expanded(
              child: StatCard(
                title: 'Oylik tarif',
                value: '29 000',
                hint: 'Aktiv obuna',
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatCard(
                title: 'Yillik tarif',
                value: '290 000',
                hint: 'Eng yaxshi taklif',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionTitle('To\'lovlar tarixi'),
        const SizedBox(height: AppSpacing.xs),
        AppTable(
          columns: const [
            DataColumn(label: Text('Foydalanuvchi')),
            DataColumn(label: Text('Tarif')),
            DataColumn(label: Text('Summa')),
            DataColumn(label: Text('To\'lov usuli')),
            DataColumn(label: Text('Status')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('Aziza Karimova')),
              DataCell(Text('Oylik')),
              DataCell(Text('29 000 so\'m')),
              DataCell(Text('Click')),
              DataCell(StatusBadge(label: 'Muvaffaqiyatli', good: true)),
            ]),
            DataRow(cells: [
              DataCell(Text('Bobur Sharipov')),
              DataCell(Text('Yillik')),
              DataCell(Text('290 000 so\'m')),
              DataCell(Text('Payme')),
              DataCell(StatusBadge(label: 'Kutilmoqda', good: true)),
            ]),
          ],
        ),
      ],
    );
  }
}
