import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../controllers/chats_controller.dart';
import '../models/chat_thread_model.dart';
import '../services/chat_pharmacy_service.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/chats_header.dart';
import '../widgets/participating_pharmacies_strip.dart';
import 'chat_detail_screen.dart';
import 'chat_search_delegate.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatsController controller = Get.put(ChatsController());
  final Color _primaryColor = const Color(0xFF5EABD6);

  final Set<String> _expandedPharmacyIds = <String>{};

  bool _isExpanded(String pharmacyId) =>
      _expandedPharmacyIds.contains(pharmacyId);

  void _toggleExpanded(String pharmacyId) {
    setState(() {
      if (_expandedPharmacyIds.contains(pharmacyId)) {
        _expandedPharmacyIds.remove(pharmacyId);
      } else {
        _expandedPharmacyIds.add(pharmacyId);
      }
    });
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: ChatSearchDelegate(
        controller: controller,
        primaryColor: _primaryColor,
      ),
    );
  }

  int _totalUnreadCount() {
    return controller.visibleThreads.fold<int>(
      0,
      (sum, thread) => sum + thread.userUnreadCount,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.messages,
              size: 62,
              color: _primaryColor.withOpacity(0.45),
            ),
            const SizedBox(height: 14),
            const Text(
              'لا توجد دردشات حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر هنا فقط الدردشات المرتبطة بالطلبات مع الصيدليات.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedCard({
    required BuildContext context,
    required String pharmacyId,
    required List<ChatThread> threads,
  }) {
    final latest = threads.first;
    final unreadCount = threads.fold<int>(
      0,
      (sum, t) => sum + t.userUnreadCount,
    );

    final isExpanded = _isExpanded(pharmacyId);

    return StreamBuilder<PharmacyModel?>(
      stream: ChatPharmacyService.instance.watchPharmacyById(pharmacyId),
      builder: (context, pharmacySnapshot) {
        final pharmacy = pharmacySnapshot.data;

        final pharmacyName = pharmacy?.displayName ?? latest.pharmacyName;
        final pharmacyImageUrl = pharmacy?.imageUrl ?? latest.pharmacyImageUrl;
        final pharmacyIsOnline = pharmacy?.isOnline ?? latest.pharmacyIsOnline;
        final hasImage = pharmacyImageUrl.trim().isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isExpanded
                  ? _primaryColor.withOpacity(0.22)
                  : const Color(0xFFE7EEF6),
              width: isExpanded ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(isExpanded ? 0.09 : 0.05),
                blurRadius: isExpanded ? 24 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _toggleExpanded(pharmacyId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFF4F8FC),
                            backgroundImage: hasImage
                                ? NetworkImage(pharmacyImageUrl)
                                : null,
                            child: !hasImage
                                ? Icon(
                                    Icons.local_pharmacy,
                                    color: _primaryColor,
                                  )
                                : null,
                          ),
                          if (pharmacyIsOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 11,
                                height: 11,
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
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${threads.length} طلب',
                                    style: const TextStyle(
                                      color: Color(0xFF5EABD6),
                                      fontSize: 10.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isExpanded
                                        ? 'إخفاء المحادثات'
                                        : 'عرض المحادثات داخل الكارد',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12.1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _primaryColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: List.generate(threads.length, (index) {
                      final thread = threads[index];

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == threads.length - 1 ? 0 : 8,
                        ),
                        child: ChatListItem(
                          thread: thread,
                          primaryColor: _primaryColor,
                          onTap: () {
                            Get.to(() => ChatDetailScreen(thread: thread));
                          },
                          onDelete: () async {
                            await controller.deleteThread(thread.chatId);
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    return Obx(() {
      final grouped = controller.groupedVisibleThreads;

      if (grouped.isEmpty) {
        return _buildEmptyState();
      }

      final groups = grouped.entries.toList()
        ..sort(
          (a, b) => b.value.first.lastMessageTime.compareTo(
            a.value.first.lastMessageTime,
          ),
        );

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        itemCount: groups.length,
        itemBuilder: (_, index) {
          final entry = groups[index];
          return _buildGroupedCard(
            context: context,
            pharmacyId: entry.key,
            threads: entry.value,
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _primaryColor,
        body: Column(
          children: [
            Obx(() {
              final totalCount = controller.visibleThreads.length;
              final unreadCount = _totalUnreadCount();

              return ChatsHeader(
                totalCount: totalCount,
                unreadCount: unreadCount,
                onSearchTap: _openSearch,
              );
            }),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7FAFD),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: Column(
                  children: [
                    Obx(
                      () => ParticipatingPharmaciesStrip(
                        pharmacies: controller.pharmacies,
                        selectedPharmacyId: controller.selectedPharmacyId.value,
                        onSelected: (pharmacyId) {
                          controller.selectPharmacy(pharmacyId);

                          if (pharmacyId != null &&
                              pharmacyId.trim().isNotEmpty) {
                            setState(() {
                              _expandedPharmacyIds.add(pharmacyId);
                            });
                          }
                        },
                        primaryColor: _primaryColor,
                      ),
                    ),
                    Expanded(
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: _primaryColor,
                            ),
                          );
                        }
                        return _buildGroupedList(context);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
