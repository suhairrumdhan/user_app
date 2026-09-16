import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/reminders_controller.dart';
import '../data/models/appointment_reminder_model.dart';
import '../data/models/medication_reminder_model.dart';
import 'add_medication_reminder_page.dart';
import '../widgets/action_sheet.dart';
import '../widgets/owner_badge.dart';
import '../widgets/time_chip.dart';

class ReminderDetailsPage extends StatelessWidget {
  final int reminderId;
  final String reminderType; // medication | appointment

  const ReminderDetailsPage({
    super.key,
    required this.reminderId,
    required this.reminderType,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSecondaryColor = Color(0xFF7BC4EA);
  static const Color rLightColor = Color(0xFFF5FBFF);
  static const Color rTextDarkColor = Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    final RemindersController controller = Get.find<RemindersController>();

    return Scaffold(
      backgroundColor: rPrimaryColor,
      body: SafeArea(
        child: Obx(() {
          if (reminderType == 'medication') {
            final reminder = controller.medicationReminders.firstWhereOrNull(
              (e) => e.id == reminderId,
            );

            if (reminder == null) {
              return const Center(
                child: Text(
                  'لم يتم العثور على التذكير',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final logs =
                controller.logs
                    .where(
                      (e) =>
                          e.reminderType == 'medication' &&
                          e.reminderLocalId == reminder.id,
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return _MedicationDetailsBody(
              reminder: reminder,
              logsCount: logs.length,
              controller: controller,
            );
          }

          final reminder = controller.appointmentReminders.firstWhereOrNull(
            (e) => e.id == reminderId,
          );

          if (reminder == null) {
            return const Center(
              child: Text(
                'لم يتم العثور على التذكير',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final logs =
              controller.logs
                  .where(
                    (e) =>
                        e.reminderType == 'appointment' &&
                        e.reminderLocalId == reminder.id,
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return _AppointmentDetailsBody(
            reminder: reminder,
            logsCount: logs.length,
            controller: controller,
          );
        }),
      ),
    );
  }
}

class _MedicationDetailsBody extends StatelessWidget {
  final MedicationReminderModel reminder;
  final int logsCount;
  final RemindersController controller;

  const _MedicationDetailsBody({
    required this.reminder,
    required this.logsCount,
    required this.controller,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSecondaryColor = Color(0xFF7BC4EA);
  static const Color rLightColor = Color(0xFFF5FBFF);
  static const Color rTextDarkColor = Color(0xFF2C3E50);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تفاصيل التذكير',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Iconsax.edit, color: Colors.white),
                onPressed: () async {
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddMedicationReminderPage(reminder: reminder),
                    ),
                  );
                  if (updated == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث التذكير بنجاح')),
                    );
                  }
                },
              ),
              GestureDetector(
                onTap: () => ReminderActionSheet.showForMedication(
                  context: context,
                  reminder: reminder,
                  controller: controller,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.more, color: rPrimaryColor),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [rPrimaryColor, rSecondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.medicineName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (reminder.dosage != null &&
                          reminder.dosage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reminder.dosage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OwnerBadge(owner: reminder.owner),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoBox(
                  title: 'الحالة',
                  value: reminder.status == 'active' ? 'نشط' : 'متوقف',
                  icon: reminder.status == 'active'
                      ? Iconsax.notification_status
                      : Iconsax.pause_circle,
                ),
                const SizedBox(height: 12),
                _InfoBox(
                  title: 'تاريخ البداية',
                  value:
                      '${reminder.startDate.year}/${reminder.startDate.month}/${reminder.startDate.day}',
                  icon: Iconsax.calendar_1,
                ),
                const SizedBox(height: 12),
                _InfoBox(
                  title: 'تاريخ النهاية',
                  value: reminder.endDate == null
                      ? 'غير محدد'
                      : '${reminder.endDate!.year}/${reminder.endDate!.month}/${reminder.endDate!.day}',
                  icon: Iconsax.calendar_remove,
                ),
                if (reminder.route != null &&
                    reminder.route!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBox(
                    title: 'طريقة الاستخدام',
                    value: reminder.route!,
                    icon: Iconsax.health,
                  ),
                ],
                if (reminder.notes != null &&
                    reminder.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBox(
                    title: 'ملاحظات',
                    value: reminder.notes!,
                    icon: Iconsax.note_1,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: rLightColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أوقات التذكير',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rTextDarkColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reminder.times
                            .map((e) => TimeChip(time: e))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        title: 'تم الأخذ',
                        icon: Iconsax.tick_circle,
                        color: const Color(0xFF4CAF50),
                        onTap: () => controller.markMedicationTaken(reminder),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        title: 'تأجيل',
                        icon: Iconsax.timer_pause,
                        color: const Color(0xFFFF9800),
                        onTap: () => controller.snoozeMedication(reminder),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoBox(
                  title: 'عدد العمليات المسجلة',
                  value: '$logsCount',
                  icon: Iconsax.note_1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentDetailsBody extends StatelessWidget {
  final AppointmentReminderModel reminder;
  final int logsCount;
  final RemindersController controller;

  const _AppointmentDetailsBody({
    required this.reminder,
    required this.logsCount,
    required this.controller,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSecondaryColor = Color(0xFF7BC4EA);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'تفاصيل الموعد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => ReminderActionSheet.showForAppointment(
                  context: context,
                  reminder: reminder,
                  controller: controller,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.more, color: rPrimaryColor),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [rPrimaryColor, rSecondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OwnerBadge(owner: reminder.owner),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoBox(
                  title: 'الحالة',
                  value: reminder.status == 'active' ? 'نشط' : 'متوقف',
                  icon: reminder.status == 'active'
                      ? Iconsax.notification_status
                      : Iconsax.pause_circle,
                ),
                const SizedBox(height: 12),
                _InfoBox(
                  title: 'الموعد',
                  value:
                      '${reminder.appointmentDateTime.year}/${reminder.appointmentDateTime.month}/${reminder.appointmentDateTime.day} • ${reminder.appointmentDateTime.hour.toString().padLeft(2, '0')}:${reminder.appointmentDateTime.minute.toString().padLeft(2, '0')}',
                  icon: Iconsax.calendar_1,
                ),
                const SizedBox(height: 12),
                _InfoBox(
                  title: 'التذكير قبل الموعد',
                  value: '${reminder.remindBeforeMinutes} دقيقة',
                  icon: Iconsax.clock,
                ),
                if (reminder.location != null &&
                    reminder.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBox(
                    title: 'المكان',
                    value: reminder.location!,
                    icon: Iconsax.location,
                  ),
                ],
                if (reminder.notes != null &&
                    reminder.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBox(
                    title: 'ملاحظات',
                    value: reminder.notes!,
                    icon: Iconsax.note_1,
                  ),
                ],
                const SizedBox(height: 12),
                _InfoBox(
                  title: 'عدد العمليات المسجلة',
                  value: '$logsCount',
                  icon: Iconsax.note_1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  static const Color rPrimaryColor = Color(0xFF5EABD6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rPrimaryColor.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: rPrimaryColor, size: 20),
          const SizedBox(width: 10),
          Text(
            '$title: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
