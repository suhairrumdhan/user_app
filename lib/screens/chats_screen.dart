import 'package:flutter/material.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final List<Map<String, dynamic>> _pharmacies = [
    {
      'id': '1',
      'name': 'صيدلية النور',
      'image': 'assets/pharmacy1.jpg',
      'lastMessage': 'الدواء متوفر الآن',
      'time': '10:30 ص',
      'unread': 2,
      'isOnline': true,
      'isActive': true,
    },
    {
      'id': '2',
      'name': 'صيدلية الحياة',
      'image': 'assets/pharmacy2.jpg',
      'lastMessage': 'تم توصيل طلبك',
      'time': 'أمس',
      'unread': 0,
      'isOnline': true,
      'isActive': true,
    },
    {
      'id': '3',
      'name': 'صيدلية الشفاء',
      'image': 'assets/pharmacy3.jpg',
      'lastMessage': 'هل تحتاج مساعدة؟',
      'time': 'الثلاثاء',
      'unread': 1,
      'isOnline': false,
      'isActive': false,
    },
  ];

  final List<Map<String, dynamic>> _favorites = [
    {
      'id': '1',
      'name': 'صيدلية النور',
      'image': 'assets/pharmacy1.jpg',
      'isOnline': true,
    },
    {
      'id': '2',
      'name': 'صيدلية الحياة',
      'image': 'assets/pharmacy2.jpg',
      'isOnline': true,
    },
    {
      'id': '4',
      'name': 'صيدلية الأمل',
      'image': 'assets/pharmacy4.jpg',
      'isOnline': true,
    },
    {
      'id': '5',
      'name': 'صيدلية المدينة',
      'image': 'assets/pharmacy5.jpg',
      'isOnline': false,
    },
  ];

  // Colors matching the original design
  final Color pPrimaryColor = Color(0xFF5EABD6);
  final Color pSecondaryColor = Color(0xFF4CAF50);
  final Color pMedColor = Color(0xFF757575);
  final double pDefaultPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pPrimaryColor,
      appBar: AppBar(
        backgroundColor: pPrimaryColor,
        title: Text(
          'الدردشات',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearch(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: pPrimaryColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
            ),
          ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  // Favourite Contacts Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.near_me_rounded, color: pPrimaryColor),
                        Text(
                          '    الصيدليات القريبة',
                          style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w800
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Horizontal list of favorite pharmacies
                  Container(
                    height: 110.0,
                    child: ListView.builder(
                      padding: EdgeInsets.only(left: 10.0, right: 10.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: _favorites.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 30.0,
                                    backgroundColor: pPrimaryColor.withOpacity(0.2),
                                    child: Icon(Icons.local_pharmacy, color: pPrimaryColor, size: 24),
                                  ),
                                  if (_favorites[index]['isOnline'])
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 15,
                                        height: 15,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).scaffoldBackgroundColor,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                              SizedBox(height: 6.0),
                              Text(
                                _favorites[index]['name'],
                                style: TextStyle(
                                    color: Colors.grey[850],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.0
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Chat List
                  Expanded(
                    child: Container(
                      child: ListView.builder(
                        itemCount: _pharmacies.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: pDefaultPadding,
                                vertical: pDefaultPadding * 0.75
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: pPrimaryColor.withOpacity(0.2),
                                      child: Icon(Icons.local_pharmacy, color: pPrimaryColor),
                                    ),
                                    if (_pharmacies[index]['isActive'])
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 15,
                                          height: 15,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context).scaffoldBackgroundColor,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: pDefaultPadding),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _pharmacies[index]['name'],
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Opacity(
                                          opacity: 0.7,
                                          child: Text(
                                            _pharmacies[index]['lastMessage'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Opacity(
                                      opacity: 0.7,
                                      child: Text(
                                        _pharmacies[index]['time'],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (_pharmacies[index]['unread'] > 0) ...[
                                      SizedBox(height: 4),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: pPrimaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _pharmacies[index]['unread'].toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
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
        onPressed: () {},
        backgroundColor: pPrimaryColor,
        child: Icon(
          Icons.person_add_alt_1_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: PharmacySearch(),
    );
  }
}

class PharmacySearch extends SearchDelegate<String> {
  final pharmacies = [
    'صيدلية النور',
    'صيدلية الحياة',
    'صيدلية الشفاء',
    'صيدلية الأمل',
    'صيدلية المدينة',
    'صيدلية النهضة',
    'صيدلية التعاون',
  ];

  final recentSearches = [
    'صيدلية النور',
    'صيدلية الحياة',
    'صيدلية الشفاء',
  ];

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.mic),
        onPressed: () {},
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Text('نتائج البحث لـ "$query"'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestionList = query.isEmpty
        ? recentSearches
        : pharmacies.where((element) => element.contains(query)).toList();

    return ListView.builder(
      itemBuilder: (context, index) => ListTile(
        leading: Icon(Icons.local_pharmacy, color: Color(0xFF5EABD6)),
        title: RichText(
          text: TextSpan(
            text: suggestionList[index].substring(0, query.length),
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(
                  text: suggestionList[index].substring(query.length),
                  style: TextStyle(color: Colors.grey)
              )
            ],
          ),
        ),
        onTap: () {
          query = suggestionList[index];
          showResults(context);
        },
      ),
      itemCount: suggestionList.length,
    );
  }
}

// Chat Detail Screen remains the same as in your original code
class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> pharmacy;

  const ChatDetailScreen({Key? key, required this.pharmacy}) : super(key: key);

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'مرحباً! الدواء الذي طلبته متوفر الآن', 'isMe': false, 'time': '10:25 ص'},
    {'text': 'شكراً! سآتي اليوم المساء', 'isMe': true, 'time': '10:26 ص'},
  ];

  final Color pPrimaryColor = Color(0xFF5EABD6);
  final double pDefaultPadding = 16.0;

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.insert(0, {
          'text': _messageController.text,
          'isMe': true,
          'time': 'الآن',
        });
        _messageController.clear();
      });
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: message['isMe'] ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: message['isMe'] ? pPrimaryColor : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['text'],
                  style: TextStyle(
                    color: message['isMe'] ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  message['time'],
                  style: TextStyle(
                    fontSize: 10,
                    color: message['isMe'] ? Colors.white70 : Colors.grey[600],
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pPrimaryColor,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.local_pharmacy, color: pPrimaryColor),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle
                    ),
                  ),
                )
              ],
            ),
            SizedBox(width: pDefaultPadding * 0.7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pharmacy['name'],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 1),
                Opacity(
                    opacity: 0.9,
                    child: Text(
                        'متصل الآن',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)
                    )
                )
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call, color: Colors.white),
            onPressed: (){},
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.white),
            onPressed: (){},
          ),
          SizedBox(width: pDefaultPadding * 0.2)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: pPrimaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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