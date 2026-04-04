import 'package:flutter/material.dart';
import 'package:user_application/features/pharmacy/models/pharmacy_model.dart';

import '../views/chat_detail_screen.dart';
import '../services/chat_service.dart';
import '../models/chat_models.dart';

class PharmacySearch extends SearchDelegate<String> {
  final ChatService chatService;

  PharmacySearch({required this.chatService});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
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
    return FutureBuilder<List<PharmacyModel>>(
      future: chatService.searchPharmacies(query),
      builder: (context, snapshot) {
        if (query.isEmpty) {
          return const Center(child: Text('اكتب اسم الصيدلية للبحث'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ في البحث'));
        }

        final pharmacies = snapshot.data ?? [];

        if (pharmacies.isEmpty) {
          return const Center(child: Text('لا توجد صيدليات بهذا الاسم'));
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

  Widget _buildPharmacyItem(BuildContext context, PharmacyModel pharmacy) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.withOpacity(0.1),
              backgroundImage: pharmacy.hasImage
                  ? NetworkImage(pharmacy.imageUrl)
                  : null,
              child: !pharmacy.hasImage
                  ? const Icon(Icons.local_pharmacy, color: Colors.blue)
                  : null,
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
          pharmacy.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pharmacy.displayAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              pharmacy.isOnline ? '🟢 متصل الآن' : '🔴 غير متصل',
              style: TextStyle(
                color: pharmacy.isOnline ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),

        trailing: const Icon(Icons.chat, color: Colors.blue),

        onTap: () => _startNewChat(context, pharmacy),
      ),
    );
  }

  Future<void> _startNewChat(
      BuildContext context, PharmacyModel pharmacy) async {
    try {
      /// 🔥 loading dialog احترافي
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final newChat = await chatService.createNewChat(pharmacy);

      Navigator.pop(context); // close loading

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(chat: newChat),
        ),
      );
    } catch (e) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('خطأ'),
          content: Text('فشل في بدء المحادثة'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    }
  }
}