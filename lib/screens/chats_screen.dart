import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';
import 'chat_detail_screen.dart';
import '../widgets/pharmacy_search.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final Color _primaryColor = Color(0xFF5EABD6);
  List<Chat> _chats = [];
  List<Pharmacy> _pharmacies = []; // Fixed: Added this variable
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load chats from Firebase
      final chats = await _chatService.getUserChats();

      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fixed: Changed to proper method instead of property
  Stream<List<Pharmacy>> getAllPharmacies() {
    return FirebaseFirestore.instance
        .collection('pharmacies')
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} pharmacy documents'); // Debug line
      return snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          print('Pharmacy data: ${doc.id} - $data'); // Debug line

          return Pharmacy(
            id: doc.id,
            name: data['name'] ?? 'صيدلية',
            isOnline: data['isOnline'] ?? false,
            imageUrl: data['imageUrl'],
            address: data['address'],
            distance: (data['distance'] != null) ? data['distance'].toDouble() : null,
          );
        } catch (e) {
          print('Error parsing pharmacy ${doc.id}: $e');
          // Return a default pharmacy in case of error
          return Pharmacy(
            id: doc.id,
            name: 'صيدلية',
            isOnline: false,
            imageUrl: null,
            address: null,
            distance: null,
          );
        }
      }).toList();
    })
        .handleError((error) {
      print('Firestore error: $error');
      throw error;
    });
  }

  void _navigateToChat(Chat chat) {
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
    ).then((value) {
      // When returning from search, update the list if needed
      _loadData();
    });
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return days[dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    final bool isTablet = screenWidth > 600;
    final bool isSmallScreen = screenWidth < 350;

    // Calculate dynamic sizes based on screen size
    final double defaultPadding = screenWidth * 0.04;
    final double avatarRadius = isTablet ? 35 : (isSmallScreen ? 22 : 25);
    final double favoriteAvatarRadius = isTablet ? 35 : (isSmallScreen ? 25 : 28);
    final double sectionHeight = screenHeight * (isTablet ? 0.16 : 0.14);
    final double iconSize = isTablet ? 28 : (isSmallScreen ? 18 : 22);
    final double titleFontSize = isTablet ? 18 : (isSmallScreen ? 13 : 15);
    final double subtitleFontSize = isTablet ? 14 : (isSmallScreen ? 10 : 12);

    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Text(
          'الدردشات',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search,
                color: Colors.white,
                size: isTablet ? 28 : 24),
            onPressed: () => _showSearch(context),
          ),
        ],
        toolbarHeight: isTablet ? 70 : kToolbarHeight,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
        children: [
          // Header spacer
          Container(
            color: _primaryColor,
            height: screenHeight * 0.02,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isTablet ? 50 : 40),
                  topRight: Radius.circular(isTablet ? 50 : 40),
                ),
              ),
              child: Column(
                children: [
                  // Nearby Pharmacies Section
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: screenHeight * 0.012,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.near_me_rounded,
                            color: _primaryColor,
                            size: isTablet ? 26 : 22),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          'الصيدليات القريبة',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w800,
                            fontSize: isTablet ? 18 : 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fixed: Using StreamBuilder for pharmacies
                  Container(
                    height: sectionHeight,
                    child: StreamBuilder<List<Pharmacy>>(
                      stream: getAllPharmacies(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: _primaryColor));
                        }

                        // In the StreamBuilder section, replace the error part with:
                        if (snapshot.hasError) {
                          print('Stream error: ${snapshot.error}');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'خطأ في تحميل الصيدليات',
                                  style: TextStyle(color: Colors.red),
                                ),
                                Text(
                                  '${snapshot.error}',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(child: Text('No pharmacies found'));
                        }

                        final pharmacies = snapshot.data!;

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                          scrollDirection: Axis.horizontal,
                          itemCount: pharmacies.length,
                          itemBuilder: (BuildContext context, int index) {
                            final pharmacy = pharmacies[index];
                            return Container(
                              constraints: BoxConstraints(
                                maxWidth: favoriteAvatarRadius * 2.5,
                                maxHeight: sectionHeight * 0.9,
                              ),
                              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.012),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: favoriteAvatarRadius * 0.9,
                                        backgroundColor: _primaryColor.withOpacity(0.2),
                                        child: Icon(Icons.local_pharmacy,
                                            color: _primaryColor,
                                            size: iconSize * 0.9),
                                      ),
                                      if (pharmacy.isOnline)
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Container(
                                            width: isTablet ? 14 : (isSmallScreen ? 8 : 12),
                                            height: isTablet ? 14 : (isSmallScreen ? 8 : 12),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                  SizedBox(height: screenHeight * 0.004),
                                  Flexible(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        pharmacy.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[850],
                                          fontWeight: FontWeight.w600,
                                          fontSize: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Chat List Section Title
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: screenHeight * 0.012,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.chat_rounded,
                            color: _primaryColor,
                            size: isTablet ? 26 : 22),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          'المحادثات',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w800,
                            fontSize: isTablet ? 18 : 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chat List
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                      child: _chats.isEmpty
                          ? Center(
                        child: Text(
                          'لا توجد محادثات',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                          : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (BuildContext context, int index) {
                          final chat = _chats[index];
                          return GestureDetector(
                            onTap: () => _navigateToChat(chat),
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: defaultPadding * 0.5,
                                vertical: defaultPadding * 0.3,
                              ),
                              padding: EdgeInsets.all(defaultPadding * 0.6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(isTablet ? 18 : 12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: avatarRadius * 0.9,
                                        backgroundColor: _primaryColor.withOpacity(0.2),
                                        child: Icon(Icons.local_pharmacy,
                                            color: _primaryColor,
                                            size: iconSize * 0.9),
                                      ),
                                      if (chat.pharmacy.isOnline)
                                        Positioned(
                                          right: 1,
                                          bottom: 1,
                                          child: Container(
                                            width: isTablet ? 16 : (isSmallScreen ? 10 : 12),
                                            height: isTablet ? 16 : (isSmallScreen ? 10 : 12),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: isTablet ? 2 : 1.5,
                                              ),
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                  SizedBox(width: defaultPadding * 0.8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chat.pharmacy.name,
                                          style: TextStyle(
                                            fontSize: titleFontSize * 0.9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                        SizedBox(height: screenHeight * 0.004),
                                        Opacity(
                                          opacity: 0.7,
                                          child: Text(
                                            chat.lastMessage,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: subtitleFontSize * 0.9,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Opacity(
                                        opacity: 0.7,
                                        child: Text(
                                          _formatTime(chat.lastMessageTime),
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: isTablet ? 12 : (isSmallScreen ? 8 : 10),
                                          ),
                                        ),
                                      ),
                                      if (chat.unreadCount > 0) ...[
                                        SizedBox(height: screenHeight * 0.003),
                                        Container(
                                          width: isTablet ? 22 : (isSmallScreen ? 14 : 18),
                                          height: isTablet ? 22 : (isSmallScreen ? 14 : 18),
                                          decoration: BoxDecoration(
                                            color: _primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              chat.unreadCount.toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isTablet ? 11 : (isSmallScreen ? 7 : 9),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add functionality for adding new contacts
        },
        backgroundColor: _primaryColor,
        child: Icon(
          Icons.person_add_alt_1_rounded,
          color: Colors.white,
          size: isTablet ? 28 : 20,
        ),
        mini: isSmallScreen,
        elevation: 2,
      ),
    );
  }
}