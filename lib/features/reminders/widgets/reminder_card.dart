import 'package:flutter/material.dart';

class ReminderCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color borderColor;

  const ReminderCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor = const Color(0xFFE3F2FD),
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: card,
    );
  }
}