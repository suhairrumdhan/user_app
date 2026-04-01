import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({Key? key, required this.chat}) : super(key: key);

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final Color _primaryColor = Color(0xFF5EABD6);
  List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }
  void _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(widget.chat.id);
      setState(() {
        _messages = messages.reversed.toList(); // عكس ترتيب الرسائل
      });
    } catch (e) {
      print('Error loading messages: $e');
    }
  }



  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      try {
        // ✅ استخدام الدالة الجديدة التي تستخدم UserController
        await _chatService.sendMessage(
          chatId: widget.chat.id,
          text: _messageController.text.trim(),
          isMe: true,
        );
        _messageController.clear();
        _loadMessages(); // إعادة تحميل الرسائل بعد الإرسال
      } catch (e) {
        print('Error sending message: $e');
        // عرض رسالة خطأ للمستخدم
        Get.snackbar(
          'خطأ',
          'فشل في إرسال الرسالة: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
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
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final bool isTablet = screenWidth > 600;
    final bool isSmallScreen = screenWidth < 350;

    final double messageFontSize = isTablet ? 16 : (isSmallScreen ? 12 : 14);
    final double timeFontSize = isTablet ? 12 : (isSmallScreen ? 8 : 10);
    final double bubblePadding = isTablet ? 16 : (isSmallScreen ? 8 : 12);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: isTablet ? 6 : 4,
        horizontal: isTablet ? 20 : 16,
      ),
      child: Row(
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth * (isTablet ? 0.6 : 0.7),
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
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.isMe ? Colors.white : Colors.black87,
                    fontSize: messageFontSize,
                  ),
                ),
                SizedBox(height: isTablet ? 4 : 2),
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
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    final bool isTablet = screenWidth > 600;
    final bool isSmallScreen = screenWidth < 350;

    // حساب الأحجام الديناميكية
    final double defaultPadding = screenWidth * 0.04;
    final double appBarAvatarRadius = isTablet ? 25 : (isSmallScreen ? 18 : 20);
    final double iconSize = isTablet ? 28 : (isSmallScreen ? 20 : 24);
    final double titleFontSize = isTablet ? 18 : (isSmallScreen ? 14 : 16);
    final double subtitleFontSize = isTablet ? 14 : (isSmallScreen ? 11 : 13);
    final double inputHeight = isTablet ? 70 : (isSmallScreen ? 50 : 60);

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
                  child: Icon(Icons.local_pharmacy,
                      color: _primaryColor,
                      size: iconSize),
                ),
                if (widget.chat.pharmacy.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                      height: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
              ],
            ),
            SizedBox(width: defaultPadding * 0.7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.pharmacy.pharmacyName,
                    style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w500
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Opacity(
                    opacity: 0.9,
                    child: Text(
                      widget.chat.pharmacy.isOnline ? 'متصل الآن' : 'غير متصل',
                      style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w400
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call,
                color: Colors.white,
                size: iconSize),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.videocam,
                color: Colors.white,
                size: iconSize),
            onPressed: () {},
          ),
          SizedBox(width: defaultPadding * 0.2)
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
              child: _messages.isEmpty
                  ? Center(
                child: Text(
                  'لا توجد رسائل بعد',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    color: Colors.grey[600],
                  ),
                ),
              )
                  : ListView.builder(
                reverse: true,
                padding: EdgeInsets.only(
                  top: screenHeight * 0.02,
                  bottom: screenHeight * 0.01,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: defaultPadding,
              vertical: isTablet ? 20 : (isSmallScreen ? 12 : 16),
            ),
            decoration: BoxDecoration(
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
                  child: Container(
                    height: inputHeight * 0.7,
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 30 : 24),
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
                Container(
                  width: inputHeight * 0.7,
                  height: inputHeight * 0.7,
                  child: FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: _primaryColor,
                    child: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: isTablet ? 28 : (isSmallScreen ? 18 : 24),
                    ),
                    elevation: 2,
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