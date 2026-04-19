import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/reminders_controller.dart';
import '../widgets/appointment_card.dart';
import '../widgets/reminder_empty_state.dart';

class AppointmentRemindersTab extends StatelessWidget {
  final RemindersController controller;

  const AppointmentRemindersTab({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reminders = [...controller.appointmentReminders]
        ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));

      if (reminders.isEmpty) {
        return const ReminderEmptyState(
          icon: Icons.calendar_month_outlined,
          title: 'لا توجد مواعيد',
          subTitle: 'أضف موعدًا صحيًا وسيظهر هنا مع التذكير المناسب',
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: reminders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, index) {
          return AppointmentCard(
            reminder: reminders[index],
            controller: controller,
          );
        },
      );
    });
  }
}