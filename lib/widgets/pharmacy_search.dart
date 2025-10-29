import 'package:flutter/material.dart';
import '../screens/chat_detail_screen.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';

class PharmacySearch extends SearchDelegate<String> {
  final ChatService chatService;

  PharmacySearch({required this.chatService});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<Pharmacy>>(
      future: chatService.searchPharmacies(query),
      builder: (context, snapshot) {
        if (query.isEmpty) {
          return Center(
            child: Text('اكتب اسم الصيدلية للبحث'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في البحث'));
        }

        final pharmacies = snapshot.data ?? [];

        if (pharmacies.isEmpty) {
          return Center(child: Text('لا توجد صيدليات بهذا الاسم'));
        }

        return ListView.builder(
          itemCount: pharmacies.length,
          itemBuilder: (context, index) {
            final pharmacy = pharmacies[index];
            return _buildPharmacyItem(context, pharmacy);
          },
        );
      },
    );
  }

  Widget _buildPharmacyItem(BuildContext context, Pharmacy pharmacy) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.2),
              child: Icon(Icons.local_pharmacy, color: Colors.blue),
            ),
            if (pharmacy.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          pharmacy.name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pharmacy.address != null) Text(pharmacy.address!),
            Text(
              pharmacy.isOnline ? '🟢 متصل الآن' : '🔴 غير متصل',
              style: TextStyle(
                color: pharmacy.isOnline ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.chat, color: Colors.blue),
        onTap: () => _startNewChat(context, pharmacy),
      ),
    );
  }

  Future<void> _startNewChat(BuildContext context, Pharmacy pharmacy) async {
    try {
      // عرض دائرة تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // ✅ إنشاء محادثة جديدة (بدون تمرير userId - الخدمة تجلبه من الـ Controller)
      final newChat = await chatService.createNewChat(pharmacy);

      // إخفاء دائرة التحميل
      Navigator.of(context).pop();

      // الانتقال إلى شاشة المحادثة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(chat: newChat),
        ),
      );

    } catch (e) {
      // إخفاء دائرة التحميل في حالة الخطأ
      Navigator.of(context).pop();

      // عرض رسالة خطأ
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('خطأ'),
          content: Text('فشل في بدء المحادثة: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }
}