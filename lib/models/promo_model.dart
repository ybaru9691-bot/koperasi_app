import 'package:flutter/material.dart';

/// Model Data untuk Banner Promo / Informasi Koperasi
class PromoModel {
  final String id;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color backgroundColor;

  const PromoModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.backgroundColor,
  });

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    return PromoModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      badgeText: json['badge_text'] as String? ?? 'INFO',
      backgroundColor: const Color(0xFF137A43),
    );
  }
}
