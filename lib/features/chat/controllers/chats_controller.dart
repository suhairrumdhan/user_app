import 'dart:async';

import 'package:get/get.dart';
import '../models/chat_thread_model.dart';
import '../services/chat_search_service.dart';
import '../services/chat_service.dart';

class ChatsController extends GetxController {
  final ChatService _chatService = ChatService.instance;
  final ChatSearchService _searchService = ChatSearchService.instance;

  StreamSubscription<List<ChatThread>>? _threadsSub;
  StreamSubscription<int>? _unreadSub;

  final RxBool isLoading = true.obs;
  final RxList<ChatThread> allThreads = <ChatThread>[].obs;
  final RxList<ChatThread> visibleThreads = <ChatThread>[].obs;
  final RxList<ParticipatingPharmacySummary> pharmacies =
      <ParticipatingPharmacySummary>[].obs;

  final RxnString selectedPharmacyId = RxnString();
  final RxString searchQuery = ''.obs;
  final RxInt totalUnreadCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _listenThreads();
    _listenUnreadCount();
  }

  void _listenThreads() {
    _threadsSub?.cancel();
    _threadsSub = _chatService.getUserChatsStream().listen((threads) {
      allThreads.assignAll(threads);
      _rebuild();
      isLoading.value = false;
    });
  }

  void _listenUnreadCount() {
    _unreadSub?.cancel();
    _unreadSub = _chatService.getUnreadCountStream().listen((count) {
      totalUnreadCount.value = count;
    });
  }

  void setSearchQuery(String value) {
    searchQuery.value = value.trim();
    _rebuild();
  }

  void selectPharmacy(String? pharmacyId) {
    if (selectedPharmacyId.value == pharmacyId) {
      selectedPharmacyId.value = null;
    } else {
      selectedPharmacyId.value = pharmacyId;
    }
    _rebuild();
  }

  void clearFilters() {
    selectedPharmacyId.value = null;
    searchQuery.value = '';
    _rebuild();
  }

  void _rebuild() {
    final filtered = _applyFilters(allThreads);
    visibleThreads.assignAll(filtered);
    pharmacies.assignAll(_chatService.buildPharmacySummaries(allThreads));
  }

  List<ChatThread> _applyFilters(List<ChatThread> threads) {
    Iterable<ChatThread> current = threads;

    if ((selectedPharmacyId.value ?? '').isNotEmpty) {
      current = current.where(
            (t) => t.pharmacyId == selectedPharmacyId.value,
      );
    }

    final searched = _searchService.filterThreads(
      current.toList(),
      searchQuery.value,
    );

    return searched;
  }

  Map<String, List<ChatThread>> get groupedVisibleThreads =>
      _chatService.groupThreadsByPharmacy(visibleThreads);

  Future<void> deleteThread(String chatId) async {
    await _chatService.deleteChat(chatId);
  }

  @override
  void onClose() {
    _threadsSub?.cancel();
    _unreadSub?.cancel();
    super.onClose();
  }
}