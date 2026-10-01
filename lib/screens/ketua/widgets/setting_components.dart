import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// 📦 CARD CONTAINER REUSABLE UNTUK SETTING SECTION
class SettingSectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  const SettingSectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adminNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// ✏️ INPUT FIELD REUSABLE UNTUK CURRENCY / PERCENTAGE / TEXT
class SettingInputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? prefixText;
  final String? suffixText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const SettingInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefixText,
    this.suffixText,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12.5),
              prefixText: prefixText != null ? '$prefixText ' : null,
              prefixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              suffixText: suffixText != null ? ' $suffixText' : null,
              suffixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔘 TOGGLE SWITCH LIST TILE REUSABLE
class SettingToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.adminNavy)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        value: value,
        activeTrackColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}
