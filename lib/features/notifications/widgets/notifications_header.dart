import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';

class NotificationsHeader extends StatelessWidget {
  final int totalCount;
  final int unreadCount;
  final VoidCallback? onMarkAllAsRead;
  final bool isProcessing;

  const NotificationsHeader({
    super.key,
    required this.totalCount,
    required this.unreadCount,
    this.onMarkAllAsRead,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [SearchUiColors.primary, SearchUiColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Iconsax.notification_bing,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الإشعارات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تابعي آخر التحديثات والتنبيهات المهمة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton.icon(
                      onPressed: isProcessing ? null : onMarkAllAsRead,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.10),
                      ),
                      icon: isProcessing
                          ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Iconsax.tick_circle,
                        size: 16,
                      ),
                      label: const Text(
                        'قراءة الكل',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

