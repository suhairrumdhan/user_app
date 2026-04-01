import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/health_record_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/family_controller.dart';

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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              widget.color.withOpacity(0.03),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: widget.color.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildContent(currentItems),
            const SizedBox(height: 16),
            _buildEditButton(currentItems),
          ],
        ),
      );
    });
  }

  /// 🔹 Header حديث
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(widget.icon, color: widget.color, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "يمكنك تعديل البيانات",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 🔹 المحتوى (Chips)
  /// 🔹 المحتوى (Chips)
  Widget _buildContent(List<String> items) {
    // ✅ تعديل: عرض Dropdown لفصيلة الدم حتى لو كانت فارغة
    if (widget.fieldType == 'bloodType') {
      return _buildBloodType(items);
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(widget.icon, color: Colors.black26, size: 40),
            const SizedBox(height: 8),
            Text(
              widget.emptyMessage,
              style: TextStyle(color: Colors.black26),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.color,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 🩸 فصيلة الدم - تعديل ليعرض القائمة حتى لو كانت فارغة
  Widget _buildBloodType(List<String> items) {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final selected = items.isNotEmpty ? items.first : null;

    return DropdownButtonFormField<String>(
      value: selected,
      hint: Text(
        'اختر فصيلة الدم',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(Iconsax.drop, color: widget.color, size: 20),
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
  /// 🔹 زر التعديل
  Widget _buildEditButton(List<String> items) {
    if (widget.fieldType == 'bloodType') return const SizedBox();

    return SizedBox(
      width: double.infinity,
      child: Obx(() => ElevatedButton(
        onPressed: widget.controller.isUpdating.value
            ? null
            : () => _showDialog(items),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: widget.controller.isUpdating.value
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
            'تعديل',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
        ),
      )),
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
    if (_itemController.text.trim().isEmpty) return;

    setDialogState(() {
      _tempItems.add(_itemController.text.trim());
    });

    _itemController.clear();
  }

  /// 🧾 Dialog التعديل
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
                color: widget.color.withOpacity(0.15),
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

                  /// 🔹 الهيدر
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "تعديل ${widget.title}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 الإدخال
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _itemController,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: "أدخل قيمة...",
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
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
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// 🔹 العناصر (Chips)
                  if (_tempItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "لا توجد عناصر",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tempItems.map((item) {
                        return Chip(
                          label: Text(item),
                          backgroundColor: widget.color.withOpacity(0.1),
                          labelStyle: TextStyle(color: widget.color),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setDialogState(() {
                              _tempItems.remove(item);
                            });
                          },
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  /// 🔹 الأزرار
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
                          child: const Text("إلغاء"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Obx(() => ElevatedButton(
                          onPressed: widget.controller.isUpdating.value
                              ? null
                              : _saveItems,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                              : const Text("حفظ"),
                        )),
                      ),
                    ],
                  )
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