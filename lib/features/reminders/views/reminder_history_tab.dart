import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/reminders_controller.dart';
import '../widgets/reminder_empty_state.dart';

class ReminderHistoryTab extends StatelessWidget {
  final RemindersController controller;

  const ReminderHistoryTab({
    super.key,
    required this.controller,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rLightColor = Color(0xFFF5FBFF);
  static const Color rTextDarkColor = Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final logs = [...controller.logs]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (logs.isEmpty) {
        return const ReminderEmptyState(
          icon: Iconsax.note_1,
          title: 'لا يوجد سجل بعد',
          subTitle: 'ستظهر هنا عمليات الأخذ والتأجيل والتخطي للتذكيرات',
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final log = logs[index];
          final style = _styleForAction(log.actionType);

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: style.color.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.title ?? 'تذكير صحي',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rTextDarkColor,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${style.label} • ${log.ownerName}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: rLightColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatDateTime(log.actionAt ?? log.createdAt),
                          style: const TextStyle(
                            color: rPrimaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  static _LogStyle _styleForAction(String action) {
    switch (action) {
      case 'taken':
        return _LogStyle(
          label: 'تم الأخذ',
          color: const Color(0xFF4CAF50),
          icon: Iconsax.tick_circle,
        );
      case 'snoozed':
        return _LogStyle(
          label: 'تم التأجيل',
          color: const Color(0xFFFF9800),
          icon: Iconsax.timer_pause,
        );
      case 'skipped':
        return _LogStyle(
          label: 'تم التخطي',
          color: const Color(0xFFE57373),
          icon: Iconsax.close_circle,
        );
      default:
        return _LogStyle(
          label: 'نشاط',
          color: rPrimaryColor,
          icon: Iconsax.note_1,
        );
    }
  }

  static String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y/$m/$d • $h:$min';
  }
}

class _LogStyle {
  final String label;
  final Color color;
  final IconData icon;

  _LogStyle({
    required this.label,
    required this.color,
    required this.icon,
  });
}