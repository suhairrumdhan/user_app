import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  final Color _primaryColor = const Color(0xFF5EABD6);

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    await _chatService.markChatAsRead(widget.chat.id);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _chatService.sendMessage(
        chatId: widget.chat.id,
        text: text,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل في إرسال الرسالة',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} د';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  Widget _buildMessageBubble(Message message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 350;

    final messageFontSize = isTablet ? 16.0 : (isSmallScreen ? 12.0 : 14.0);
    final timeFontSize = isTablet ? 12.0 : (isSmallScreen ? 8.0 : 10.0);
    final bubblePadding = isTablet ? 16.0 : (isSmallScreen ? 8.0 : 12.0);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: isTablet ? 6 : 4,
        horizontal: isTablet ? 20 : 16,
      ),
      child: Row(
        mainAxisAlignment:
        message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth * (isTablet ? 0.6 : 0.72),
              minWidth: screenWidth * 0.2,
            ),
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 12 : 8,
              horizontal: bubblePadding,
            ),
            decoration: BoxDecoration(
              color: message.isMe ? _primaryColor : Colors.grey[200],
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isImage && message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      message.imageUrl!,
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isMe ? Colors.white : Colors.black87,
                      fontSize: messageFontSize,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatMessageTime(message.timestamp),
                  style: TextStyle(
                    fontSize: timeFontSize,
                    color: message.isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 350;

    final defaultPadding = screenWidth * 0.04;
    final appBarAvatarRadius = isTablet ? 25.0 : (isSmallScreen ? 18.0 : 20.0);
    final iconSize = isTablet ? 28.0 : (isSmallScreen ? 20.0 : 24.0);
    final titleFontSize = isTablet ? 18.0 : (isSmallScreen ? 14.0 : 16.0);
    final subtitleFontSize = isTablet ? 14.0 : (isSmallScreen ? 11.0 : 13.0);
    final inputHeight = isTablet ? 70.0 : (isSmallScreen ? 50.0 : 60.0);

    final pharmacy = widget.chat.pharmacy;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: appBarAvatarRadius,
                  backgroundColor: Colors.white,
                  backgroundImage:
                  pharmacy.hasImage ? NetworkImage(pharmacy.imageUrl) : null,
                  child: !pharmacy.hasImage
                      ? Icon(
                    Icons.local_pharmacy,
                    color: _primaryColor,
                    size: iconSize,
                  )
                      : null,
                ),
                if (pharmacy.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                      height: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: defaultPadding * 0.7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pharmacy.displayName,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Opacity(
                    opacity: 0.9,
                    child: Text(
                      pharmacy.isOnline ? 'متصل الآن' : 'غير متصل',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call, color: Colors.white, size: iconSize),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.white, size: iconSize),
            onPressed: () {},
          ),
          SizedBox(width: defaultPadding * 0.2),
        ],
        toolbarHeight: isTablet ? 80 : kToolbarHeight,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _primaryColor.withOpacity(0.05),
                    _primaryColor.withOpacity(0.02),
                  ],
                ),
              ),
              child: StreamBuilder<List<Message>>(
                stream: _chatService.getMessagesStream(widget.chat.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('حدث خطأ في تحميل الرسائل'),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد رسائل بعد',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      top: screenHeight * 0.02,
                      bottom: screenHeight * 0.01,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(messages[index]);
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: defaultPadding,
              vertical: isTablet ? 20 : (isSmallScreen ? 12 : 16),
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: inputHeight * 0.7,
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(isTablet ? 30 : 24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 16,
                          vertical: isTablet ? 16 : 12,
                        ),
                        hintStyle: TextStyle(
                          fontSize: isTablet ? 16 : (isSmallScreen ? 12 : 14),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: isTablet ? 16 : (isSmallScreen ? 12 : 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: defaultPadding * 0.5),
                SizedBox(
                  width: inputHeight * 0.7,
                  height: inputHeight * 0.7,
                  child: FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: _primaryColor,
                    elevation: 2,
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: isTablet ? 28 : (isSmallScreen ? 18 : 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}