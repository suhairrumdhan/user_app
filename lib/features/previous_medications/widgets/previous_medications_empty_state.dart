import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/views/search_ui_colors.dart';

class PreviousMedicationsEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showAction;
  final String actionLabel;
  final VoidCallback? onAction;

  const PreviousMedicationsEmptyState({
    super.key,
    this.title = 'لا توجد أدوية سابقة',
    this.subtitle =
    'عند استلام طلب جديد يمكنكِ إضافة الأدوية إلى هذا السجل وربطها بالتذكيرات.',
    this.showAction = false,
    this.actionLabel = 'تحديث',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: SearchUiColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Iconsax.hospital,
                  color: SearchUiColors.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SearchUiColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13.6,
                  fontWeight: FontWeight.w600,
                  height: 1.7,
                ),
              ),
              if (showAction && onAction != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SearchUiColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Iconsax.refresh),
                  label: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}