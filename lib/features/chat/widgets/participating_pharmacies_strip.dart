import 'package:flutter/material.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../models/chat_thread_model.dart';
import '../services/chat_pharmacy_service.dart';

class ParticipatingPharmaciesStrip extends StatelessWidget {
  final List<ParticipatingPharmacySummary> pharmacies;
  final String? selectedPharmacyId;
  final ValueChanged<String?> onSelected;
  final Color primaryColor;

  const ParticipatingPharmaciesStrip({
    super.key,
    required this.pharmacies,
    required this.selectedPharmacyId,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pharmacies.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: pharmacies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = pharmacies[index];
          final isSelected = item.pharmacyId == selectedPharmacyId;

          return StreamBuilder<PharmacyModel?>(
            stream: ChatPharmacyService.instance.watchPharmacyById(
              item.pharmacyId,
            ),
            builder: (context, snapshot) {
              final pharmacy = snapshot.data;

              final pharmacyName = pharmacy?.displayName ?? item.pharmacyName;
              final pharmacyImageUrl = pharmacy?.imageUrl ?? item.pharmacyImageUrl;
              final pharmacyIsOnline = pharmacy?.isOnline ?? item.pharmacyIsOnline;
              final hasImage = pharmacyImageUrl.trim().isNotEmpty;

              return GestureDetector(
                onTap: () => onSelected(item.pharmacyId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFF4F8FC),
                              backgroundImage:
                              hasImage ? NetworkImage(pharmacyImageUrl) : null,
                              child: !hasImage
                                  ? Icon(
                                Icons.local_pharmacy,
                                color: primaryColor,
                              )
                                  : null,
                            ),
                          ),
                          if (pharmacyIsOnline)
                            Positioned(
                              right: 3,
                              bottom: 1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          if (item.hasUnread)
                            Positioned(
                              left: -4,
                              top: -4,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    item.unreadCount > 99
                                        ? '99+'
                                        : item.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pharmacyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}