import 'package:flutter/material.dart';

class BookModel {
  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.pdfUrl,
    required this.coverUrl,
    required this.coverColor,
    required this.pages,
    required this.category,
    required this.yoshGuruhi,
    required this.reads,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String pdfUrl;       // signed PDF URL (consumer endpoint re-signs)
  final String coverUrl;     // signed cover URL (optional)
  final Color coverColor;    // fallback rang
  final int pages;
  final String category;
  final String yoshGuruhi;
  final int reads;

  bool get hasCover => coverUrl.isNotEmpty;
}
