import 'package:flutter/material.dart';

class ReminderEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subTitle;
  final Widget? action;

  const ReminderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subTitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 78,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey[500],
                height: 1.6,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}