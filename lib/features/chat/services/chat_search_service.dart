import '../models/chat_thread_model.dart';

class ChatSearchService {
  ChatSearchService._();
  static final ChatSearchService instance = ChatSearchService._();

  List<ChatThread> filterThreads(
      List<ChatThread> threads,
      String query,
      ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return threads;

    return threads.where((thread) {
      return thread.pharmacyName.toLowerCase().contains(q) ||
          thread.beneficiaryName.toLowerCase().contains(q) ||
          thread.orderId.toLowerCase().contains(q) ||
          thread.lastMessage.toLowerCase().contains(q) ||
          thread.relationLabel.toLowerCase().contains(q);
    }).toList();
  }
}