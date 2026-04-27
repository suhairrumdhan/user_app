import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/reminders_controller.dart';
import '../services/local_notification_service.dart';
import '../widgets/reminder_section_header.dart';
import 'add_appointment_page.dart';
import 'add_medication_reminder_page.dart';
import 'appointment_reminders_tab.dart';
import 'medication_reminders_tab.dart';
import 'reminder_history_tab.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  static const Color rPrimaryColor = Color(0xFF5EABD6);
  static const Color rSecondaryColor = Color(0xFF7BC4EA);
  static const Color rLightColor = Color(0xFFF5FBFF);
  static const Color rTextDarkColor = Color(0xFF2C3E50);
  static const Color rSuccessColor = Color(0xFF4CAF50);
  static const Color rWarningColor = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final RemindersController controller =
    Get.isRegistered<RemindersController>()
        ? Get.find<RemindersController>()
        : Get.put(RemindersController());

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: rPrimaryColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'التذكيرات ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),

                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAddOptions(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Iconsax.add,
                          color: rPrimaryColor,
                          size: 22,
                        ),
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
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Obx(() {
                          final activeMedications = controller
                              .medicationReminders
                              .where((e) => e.status == 'active')
                              .length;
                          final activeAppointments = controller
                              .appointmentReminders
                              .where((e) => e.status == 'active')
                              .length;
                          final logsCount = controller.logs.length;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [rPrimaryColor, rSecondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: rPrimaryColor.withOpacity(0.20),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const ReminderSectionHeader(
                                  title: 'نظام التذكيرات ',
                                  subTitle:
                                  'إدارة تذكيرات الأدوية والمواعيد ',
                                  titleColor: Colors.white,
                                  subTitleColor: Colors.white,
                                  icon: Iconsax.notification_bing,
                                  iconColor: Colors.white,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SummaryBox(
                                        title: 'الأدوية',
                                        value: '$activeMedications',
                                        icon: Iconsax.book,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _SummaryBox(
                                        title: 'المواعيد',
                                        value: '$activeAppointments',
                                        icon: Iconsax.calendar_1,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _SummaryBox(
                                        title: 'السجل',
                                        value: '$logsCount',
                                        icon: Iconsax.note_1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: rLightColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: rPrimaryColor.withOpacity(0.10),
                          ),
                        ),
                        child: const TabBar(
                          dividerColor: Colors.transparent,
                          labelColor: rPrimaryColor,
                          unselectedLabelColor: Colors.black54,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.all(Radius.circular(14)),
                          ),
                          tabs: [
                            Tab(text: 'الأدوية'),
                            Tab(text: 'المواعيد'),
                            Tab(text: 'السجل'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: TabBarView(
                          children: [
                            MedicationRemindersTab(controller: controller),
                            AppointmentRemindersTab(controller: controller),
                            ReminderHistoryTab(controller: controller),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'إضافة تذكير جديد',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: rTextDarkColor,
                  ),
                ),
                const SizedBox(height: 18),
                _AddOptionTile(
                  icon: Iconsax.book,
                  title: 'تذكير دواء',
                  subTitle: 'لإنشاء مواعيد تناول دواء متكررة يوميًا',
                  color: rPrimaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => const AddMedicationReminderPage());
                  },
                ),
                const SizedBox(height: 12),
                _AddOptionTile(
                  icon: Iconsax.calendar_1,
                  title: 'تذكير موعد',
                  subTitle: 'لزيارة طبيب أو تحليل أو مراجعة صحية',
                  color: rWarningColor,
                  onTap: () {
                    Navigator.pop(context);
                    Get.to(() => const AddAppointmentPage());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.92),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subTitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subTitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FCFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subTitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_left_2, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}