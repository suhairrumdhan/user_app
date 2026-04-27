import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/health_record_controller.dart';
import '../../profile/controllers/user_controller.dart';
import '../../family/controllers/family_controller.dart';

class HealthInfoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final String emptyMessage;
  final Color color;
  final String fieldType;
  final HealthRecordController controller;
  final String personType;
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
  State<HealthInfoCard> createState() => _HealthInfoCardState();
}

class _HealthInfoCardState extends State<HealthInfoCard> {
  final TextEditingController _itemController = TextEditingController();
  List<String> _tempItems = [];

  static const Color _textPrimary = Color(0xFF2C3E50);
  static const Color _textSecondary = Color(0xFF7F8C8D);

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      List<String> currentItems = [];

      if (widget.personType == 'user') {
        final user = Get.find<UserController>().user.value;
        if (user != null) {
          switch (widget.fieldType) {
            case 'healthConditions':
              currentItems = user.healthConditions ?? [];
              break;
            case 'allergies':
              currentItems = user.allergies ?? [];
              break;
            case 'currentMedications':
              currentItems = user.currentMedications ?? [];
              break;
            case 'bloodType':
              currentItems = user.bloodType != null ? [user.bloodType!] : [];
              break;
          }
        }
      } else {
        final member = Get.find<FamilyController>()
            .members
            .firstWhereOrNull((m) => m.id == widget.personId);

        if (member != null) {
          switch (widget.fieldType) {
            case 'healthConditions':
              currentItems = member.healthConditions ?? [];
              break;
            case 'allergies':
              currentItems = member.allergies ?? [];
              break;
            case 'currentMedications':
              currentItems = member.currentMedications ?? [];
              break;
            case 'bloodType':
              currentItems = member.bloodType != null ? [member.bloodType!] : [];
              break;
          }
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: widget.color.withOpacity(0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(currentItems.length),
            const SizedBox(height: 14),
            _buildContent(currentItems),
            if (widget.fieldType != 'bloodType') ...[
              const SizedBox(height: 16),
              _buildEditButton(currentItems),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(widget.icon, color: widget.color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.fieldType == 'bloodType'
                    ? 'يمكنك تعديلها مباشرة'
                    : count > 0
                    ? '$count عنصر مسجل'
                    : 'لا توجد بيانات مسجلة',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(List<String> items) {
    if (widget.fieldType == 'bloodType') {
      return _buildBloodType(items);
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.color.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(
              widget.icon,
              color: Colors.grey[400],
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(0.10),
            ),
          ),
          child: Text(
            item,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBloodType(List<String> items) {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final selected = items.isNotEmpty ? items.first : null;

    return DropdownButtonFormField<String>(
      value: selected,
      isExpanded: true,
      hint: Text(
        'اختر فصيلة الدم',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FBFE),
        prefixIcon: Icon(Iconsax.drop3, color: widget.color, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: widget.color.withOpacity(0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: widget.color.withOpacity(0.30),
          ),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: bloodTypes.map((e) {
        return DropdownMenuItem(
          value: e,
          child: Text(
            e,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) _saveBloodType(value);
      },
    );
  }

  Widget _buildEditButton(List<String> items) {
    return SizedBox(
      width: double.infinity,
      child: Obx(
            () => ElevatedButton(
          onPressed:
          widget.controller.isUpdating.value ? null : () => _showDialog(items),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: widget.controller.isUpdating.value
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text(
            'تعديل',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _saveBloodType(String value) async {
    if (widget.personType == 'user') {
      await widget.controller.updateUserHealthRecords(bloodType: value);
    } else {
      await widget.controller.updateFamilyMemberHealthRecords(
        memberId: widget.personId,
        bloodType: value,
      );
    }
  }

  void _addItem(void Function(void Function()) setDialogState) {
    final value = _itemController.text.trim();
    if (value.isEmpty) return;
    if (_tempItems.contains(value)) {
      _itemController.clear();
      return;
    }

    setDialogState(() {
      _tempItems.add(value);
    });

    _itemController.clear();
  }

  void _showDialog(List<String> current) {
    _tempItems = List.from(current);
    _itemController.clear();

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.12),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تعديل ${widget.title}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _itemController,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'أدخل قيمة...',
                            filled: true,
                            fillColor: const Color(0xFFF8FBFE),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: widget.color.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: widget.color.withOpacity(0.28),
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _addItem(setDialogState),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _addItem(setDialogState),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.color.withOpacity(0.08),
                      ),
                    ),
                    child: _tempItems.isEmpty
                        ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'لا توجد عناصر',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                    )
                        : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tempItems.map((item) {
                          return Chip(
                            label: Text(item),
                            backgroundColor: widget.color.withOpacity(0.10),
                            labelStyle: const TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            deleteIcon:
                            const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setDialogState(() {
                                _tempItems.remove(item);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Obx(
                              () => ElevatedButton(
                            onPressed:
                            widget.controller.isUpdating.value ? null : _saveItems,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.color,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: widget.controller.isUpdating.value
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'حفظ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _saveItems() async {
    if (widget.personType == 'user') {
      await widget.controller.updateUserHealthRecords(
        healthConditions:
        widget.fieldType == 'healthConditions' ? _tempItems : null,
        allergies: widget.fieldType == 'allergies' ? _tempItems : null,
        currentMedications:
        widget.fieldType == 'currentMedications' ? _tempItems : null,
      );
    } else {
      await widget.controller.updateFamilyMemberHealthRecords(
        memberId: widget.personId,
        healthConditions:
        widget.fieldType == 'healthConditions' ? _tempItems : null,
        allergies: widget.fieldType == 'allergies' ? _tempItems : null,
        currentMedications:
        widget.fieldType == 'currentMedications' ? _tempItems : null,
      );
    }

    Get.back();
  }
}