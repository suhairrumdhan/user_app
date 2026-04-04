import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:user_application/features/pharmacy/models/pharmacy_model.dart';

import '../services/chat_service.dart';
import '../models/chat_models.dart';
import 'chat_detail_screen.dart';
import '../widgets/pharmacy_search.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final Color _primaryColor = const Color(0xFF5EABD6);

  /// 🔥 FIX: استخدام PharmacyModel الصحيح
  Stream<List<PharmacyModel>> getAllPharmacies() {
    return FirebaseFirestore.instance
        .collection('pharmacies')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PharmacyModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 🔥 فتح المحادثة + تصفير unread
  void _navigateToChat(Chat chat) async {
    await _chatService.markChatAsRead(chat.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(chat: chat),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: PharmacySearch(chatService: _chatService),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return days[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final bool isTablet = screenWidth > 600;
    final bool isSmallScreen = screenWidth < 350;

    final double padding = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: const Text('الدردشات', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearch(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(
                children: [

                  /// 🔥 قائمة الصيدليات (أعلى)
                  SizedBox(
                    height: 120,
                    child: StreamBuilder<List<PharmacyModel>>(
                      stream: getAllPharmacies(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: _primaryColor));
                        }

                        final pharmacies = snapshot.data!;

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: pharmacies.length,
                          itemBuilder: (context, index) {
                            final pharmacy = pharmacies[index];

                            return GestureDetector(
                              onTap: () async {
                                final chat = await _chatService.createNewChat(pharmacy);
                                _navigateToChat(chat);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundImage: pharmacy.hasImage
                                              ? NetworkImage(pharmacy.imageUrl!)
                                              : null,
                                          child: !pharmacy.hasImage
                                              ? const Icon(Icons.local_pharmacy)
                                              : null,
                                        ),
                                        if (pharmacy.isOnline)
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white),
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        pharmacy.displayName,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  /// 🔥 قائمة المحادثات
                  Expanded(
                    child: StreamBuilder<List<Chat>>(
                      stream: _chatService.getUserChatsStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: _primaryColor));
                        }

                        final chats = snapshot.data!;

                        return ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];

                            return Dismissible(
                              key: Key(chat.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.red,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) {
                                _chatService.deleteChat(chat.id);
                              },
                              child: ListTile(
                                onTap: () => _navigateToChat(chat),

                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: chat.pharmacy.hasImage
                                          ? NetworkImage(chat.pharmacy.imageUrl!)
                                          : null,
                                      child: !chat.pharmacy.hasImage
                                          ? const Icon(Icons.local_pharmacy)
                                          : null,
                                    ),
                                    if (chat.pharmacy.isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white),
                                          ),
                                        ),
                                      )
                                  ],
                                ),

                                title: Text(chat.pharmacy.displayName),

                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chat.lastMessagePreview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (chat.pharmacy.address != null)
                                      Text(
                                        chat.pharmacy.displayAddress,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                  ],
                                ),

                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_formatTime(chat.lastMessageTime)),

                                    if (chat.hasUnread)
                                      Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          chat.userUnreadCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}