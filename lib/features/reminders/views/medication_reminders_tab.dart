import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/reminders_controller.dart';
import '../widgets/medication_reminder_card.dart';
import '../widgets/reminder_empty_state.dart';

class MedicationRemindersTab extends StatelessWidget {
  final RemindersController controller;

  const MedicationRemindersTab({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reminders = [...controller.medicationReminders]
        ..sort((a, b) {
          if (a.status == b.status) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.status == 'active') return -1;
          if (b.status == 'active') return 1;
          return 0;
        });

      if (reminders.isEmpty) {
        return const ReminderEmptyState(
          icon: Icons.medication_outlined,
          title: 'لا توجد تذكيرات أدوية',
          subTitle: 'ابدأ بإضافة أول تذكير لتناول الأدوية في المواعيد المناسبة',
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: reminders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, index) {
          return MedicationReminderCard(
            reminder: reminders[index],
            controller: controller,
          );
        },
      );
    });
  }
}