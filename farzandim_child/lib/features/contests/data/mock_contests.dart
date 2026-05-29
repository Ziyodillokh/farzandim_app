// ─────────────────────────────────────────────────────────────────────
// MockContests — 5 aktiv + 3 yakunlangan konkurs
// ─────────────────────────────────────────────────────────────────────
//
// Kelajakda Admin panel orqali Firestore'ga joylanadigan real
// konkurslar bilan almashtiriladi.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import 'package:farzandim_child/features/contests/data/models/contest_model.dart';

class MockContests {
  MockContests._();

  static final DateTime _now = DateTime.now();

  static final List<ContestModel> active = [
    ContestModel(
      id: '1',
      title: "Iste'dod Uchquni",
      description:
          "San'at va ijodkorlik sohasidagi iste'dodli bolalar uchun",
      soha: "Iste'dod",
      ishtirokchilarSoni: 456,
      maxIshtirokchi: 1000,
      deadline: _now.add(const Duration(days: 7)),
      isActive: true,
      placeholderColor: AppColors.catPinkRose,
      placeholderIcon: Icons.palette,
      bonus: 500,
      savollarSoni: 10,
      vaqtChegarasiDaq: 15,
    ),
    ContestModel(
      id: '2',
      title: 'Zehnli Bolajon',
      description: "Aniq fanlar bo'yicha bilim sinovi",
      soha: 'Aniq fanlar',
      ishtirokchilarSoni: 1230,
      maxIshtirokchi: 1500,
      deadline: _now.add(const Duration(days: 3)),
      isActive: true,
      placeholderColor: AppColors.catLavenderDark,
      placeholderIcon: Icons.calculate,
      bonus: 700,
      savollarSoni: 15,
      vaqtChegarasiDaq: 20,
    ),
    ContestModel(
      id: '3',
      title: 'Yosh Olim',
      description: "Tabiiy fanlar bo'yicha qiziqarli savollar",
      soha: 'Tabiiy fanlar',
      ishtirokchilarSoni: 234,
      maxIshtirokchi: 800,
      deadline: _now.add(const Duration(days: 14)),
      isActive: true,
      placeholderColor: AppColors.catMint,
      placeholderIcon: Icons.science,
      bonus: 600,
      savollarSoni: 12,
      vaqtChegarasiDaq: 18,
    ),
    ContestModel(
      id: '4',
      title: 'Mantiq Sehri',
      description: 'Matematik mantiq va aql-zakovat sinovlari',
      soha: 'Matematika',
      ishtirokchilarSoni: 890,
      maxIshtirokchi: 1200,
      deadline: _now.add(const Duration(days: 5)),
      isActive: true,
      placeholderColor: AppColors.catOrangeWarm,
      placeholderIcon: Icons.psychology,
      bonus: 800,
      savollarSoni: 20,
      vaqtChegarasiDaq: 25,
    ),
    ContestModel(
      id: '5',
      title: 'Kitobxon Bolajon',
      description: "O'zbek va jahon adabiyoti bo'yicha savollar",
      soha: 'Adabiyot',
      ishtirokchilarSoni: 567,
      maxIshtirokchi: 1000,
      deadline: _now.add(const Duration(days: 10)),
      isActive: true,
      placeholderColor: AppColors.catLavender,
      placeholderIcon: Icons.menu_book,
      bonus: 550,
      savollarSoni: 15,
      vaqtChegarasiDaq: 20,
    ),
  ];

  static final List<ContestModel> finished = [
    ContestModel(
      id: 'f1',
      title: 'Bahor Bolasi 2026',
      description: "Bahorga bag'ishlangan ijodiy konkurs",
      soha: "Iste'dod",
      ishtirokchilarSoni: 1500,
      maxIshtirokchi: 1500,
      deadline: _now.subtract(const Duration(days: 14)),
      isActive: false,
      placeholderColor: AppColors.catPinkVibrant,
      placeholderIcon: Icons.local_florist,
      bonus: 1000,
      savollarSoni: 15,
      vaqtChegarasiDaq: 20,
      winnerName: 'Asilbek',
      winnerAge: 12,
      finishedDate: _now.subtract(const Duration(days: 14)),
    ),
    ContestModel(
      id: 'f2',
      title: 'Yosh Tarjimon',
      description: "Til va tarjima bo'yicha musobaqa",
      soha: 'Adabiyot',
      ishtirokchilarSoni: 800,
      maxIshtirokchi: 800,
      deadline: _now.subtract(const Duration(days: 30)),
      isActive: false,
      placeholderColor: AppColors.catGreen,
      placeholderIcon: Icons.translate,
      bonus: 750,
      savollarSoni: 12,
      vaqtChegarasiDaq: 25,
      winnerName: 'Madina',
      winnerAge: 10,
      finishedDate: _now.subtract(const Duration(days: 30)),
    ),
    ContestModel(
      id: 'f3',
      title: 'Matematika Olimpiadasi',
      description: 'Yillik matematika musobaqasi',
      soha: 'Matematika',
      ishtirokchilarSoni: 2000,
      maxIshtirokchi: 2000,
      deadline: _now.subtract(const Duration(days: 60)),
      isActive: false,
      placeholderColor: AppColors.catOrangeLight,
      placeholderIcon: Icons.functions,
      bonus: 1500,
      savollarSoni: 25,
      vaqtChegarasiDaq: 40,
      winnerName: 'Bekzod',
      winnerAge: 14,
      finishedDate: _now.subtract(const Duration(days: 60)),
    ),
  ];
}
