import 'package:flutter/material.dart';

class ReminderSectionHeader extends StatelessWidget {
  final String title;
  final String? subTitle;
  final IconData? icon;
  final Widget? trailing;
  final Color titleColor;
  final Color subTitleColor;
  final Color iconColor;

  const ReminderSectionHeader({
    super.key,
    required this.title,
    this.subTitle,
    this.icon,
    this.trailing,
    this.titleColor = const Color(0xFF2C3E50),
    this.subTitleColor = Colors.black54,
    this.iconColor = const Color(0xFF5EABD6),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null)
          Icon(icon, color: iconColor, size: 20),
        if (icon != null) const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: titleColor,
                ),
              ),
              if (subTitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subTitle!,
                  style: TextStyle(
                    color: subTitleColor,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}