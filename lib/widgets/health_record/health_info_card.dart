// widgets/health_record/health_info_card.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/health_record_controller.dart';
import '../../models/family_member_model.dart';

class HealthInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final String emptyMessage;
  final Color color;
  final String fieldType;
  final HealthRecordController controller;
  final String personType; // 'user' or 'family_member'
  final String personId;

  const HealthInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.color,
    required this.fieldType,
    required this.controller,
    required this.personType,
    required this.personId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(),
          const SizedBox(height: 8),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (items.isNotEmpty) {
      return _buildItemsList();
    } else {
      return _buildEmptyState();
    }
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8, right: 12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        onPressed: _showEditDialog,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'تعديل',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    final TextEditingController textController = TextEditingController(
      text: items.join(', '),
    );

    Get.dialog(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'تعديل $title',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أدخل العناصر مفصولة بفاصلة',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'مثال: سكري, ضغط دم, حساسية القمح',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newItems = controller.parseItemsFromText(textController.text);

                if (personType == 'user') {
                  await controller.updateUserHealthRecords(
                    healthConditions: fieldType == 'healthConditions' ? newItems : null,
                    allergies: fieldType == 'allergies' ? newItems : null,
                    currentMedications: fieldType == 'currentMedications' ? newItems : null,
                  );
                } else {
                  await controller.updateFamilyMemberHealthRecords(
                    memberId: personId,
                    healthConditions: fieldType == 'healthConditions' ? newItems : null,
                    allergies: fieldType == 'allergies' ? newItems : null,
                    currentMedications: fieldType == 'currentMedications' ? newItems : null,
                  );
                }

                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EABD6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'حفظ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}