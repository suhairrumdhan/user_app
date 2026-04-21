import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/chats_controller.dart';
import '../models/chat_thread_model.dart';
import '../widgets/chat_list_item.dart';
import 'chat_detail_screen.dart';

class ChatSearchDelegate extends SearchDelegate<String> {
  final ChatsController controller;
  final Color primaryColor;

  ChatSearchDelegate({
    required this.controller,
    required this.primaryColor,
  });

  List<ChatThread> get _results {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return controller.allThreads;

    return controller.allThreads.where((thread) {
      return thread.pharmacyName.toLowerCase().contains(q) ||
          thread.beneficiaryName.toLowerCase().contains(q) ||
          thread.lastMessage.toLowerCase().contains(q) ||
          thread.orderId.toLowerCase().contains(q) ||
          thread.relationLabel.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
  }

  @override
  String get searchFieldLabel => 'ابحث داخل الدردشات';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final results = _results;

    if (query.trim().isEmpty) {
      return const Center(
        child: Text(
          'ابحث باسم الصيدلية أو المستفيد أو نص الرسالة',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final thread = results[index];
        return ChatListItem(
          thread: thread,
          primaryColor: primaryColor,
          onTap: () {
            close(context, '');
            Get.to(() => ChatDetailScreen(thread: thread));
          },
          onDelete: null,
        );
      },
    );
  }
}