import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../pharmacy/models/pharmacy_model.dart';
import '../../prescription/models/beneficiary_model.dart';
import '../../search/models/matched_medicine_result.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';
import '../services/order_service.dart';
import '../../../shared/availability_policy.dart';
import '../../search/models/medicine_sale_quote.dart';

class ConfirmOrderSheet extends StatefulWidget {
  final PharmacyModel pharmacy;
  final BeneficiaryModel beneficiary;
  final bool useInsurance;
  final OrderRequestSource requestSource;
  final Map<String, dynamic>? metadata;
  final String? prescriptionId;
  final String? prescriptionImageUrl;
  final String? prescriptionText;

  const ConfirmOrderSheet({
    super.key,
    required this.pharmacy,
    required this.beneficiary,
    required this.useInsurance,
    required this.requestSource,
    this.metadata,
    this.prescriptionId,
    this.prescriptionImageUrl,
    this.prescriptionText,
  });

  @override
  State<ConfirmOrderSheet> createState() => _ConfirmOrderSheetState();
}

class _ConfirmOrderSheetState extends State<ConfirmOrderSheet> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  late final List<_SelectableMedicineItem> _availableMedicines;

  @override
  void initState() {
    super.initState();
    _availableMedicines = _buildAvailableMedicines();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<_SelectableMedicineItem> _buildAvailableMedicines() {
    final grouped = <String, _SelectableMedicineItem>{};
    for (final matched in widget.pharmacy.matchedMedicines) {
      final key = '${matched.matchedMedicineId}:${matched.soldByPiece}';
      final previous = grouped[key];
      if (previous != null) {
        previous.quantity++;
      } else {
        grouped[key] = _SelectableMedicineItem(match: matched);
      }
    }
    return grouped.values.toList();
  }

  List<_SelectableMedicineItem> get _selectedItems => _availableMedicines
      .where((item) => item.isSelected && item.quantity > 0)
      .toList();

  bool get _hasSelectedMedicines => _selectedItems.isNotEmpty;

  double get _selectedEstimatedTotal => _selectedItems.fold<double>(
    0,
    (sum, item) => sum + (item.match.price * item.quantity),
  );

  Future<void> _submitOrder() async {
    debugPrint(
      'ConfirmOrderSheet submit tapped: selected=${_selectedItems.length} '
      'pharmacyId=${widget.pharmacy.id}',
    );
    if (_isSubmitting) return;

    if (!_hasSelectedMedicines) {
      Get.snackbar(
        'تنبيه',
        'اختر دواءً واحدًا على الأقل لإرسال الطلب',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      debugPrint('ConfirmOrderSheet validating live inventory');
      final inventoryError = await _validateCurrentInventory();
      if (inventoryError != null) {
        debugPrint('ConfirmOrderSheet inventory rejected: $inventoryError');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(inventoryError)));
        return;
      }
      debugPrint('ConfirmOrderSheet inventory validation passed');
      final selectedMatches = _selectedItems.map((e) => e.match).toList();

      final quantitiesByMatchedMedicineId = <String, int>{
        for (final item in _selectedItems)
          '${item.match.matchedMedicineId}:${item.match.soldByPiece}':
              item.quantity,
      };

      final order = await OrderService.instance.createOrder(
        pharmacy: widget.pharmacy,
        beneficiary: widget.beneficiary,
        selectedMatches: selectedMatches,
        quantitiesByMatchedMedicineId: quantitiesByMatchedMedicineId,
        useInsurance: widget.useInsurance,
        requestSource: widget.requestSource,
        userNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        prescriptionId: widget.prescriptionId,
        prescriptionImageUrl: widget.prescriptionImageUrl,
        prescriptionText: widget.prescriptionText,
        metadata: {
          ...?widget.metadata,
          'sourceLabel': widget.requestSource.label,
          'createdFromSheet': true,
          'selectedItemsCount': _selectedItems.length,
        },
      );

      if (!mounted) return;

      await _showOrderSavedDialog(order);
      if (!mounted) return;

      Navigator.of(context).pop(order);
    } catch (e, st) {
      debugPrint('❌ ConfirmOrderSheet submit failed: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;

      Get.snackbar(
        'خطأ',
        'فشل في إرسال الطلب: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showOrderSavedDialog(OrderModel order) async {
    final orderNumber = order.orderNumber?.trim();
    final orderReference = orderNumber != null && orderNumber.isNotEmpty
        ? orderNumber
        : order.id;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            title: const Column(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: Color(0xFFE8F7EE),
                  child: Icon(
                    Iconsax.tick_circle,
                    color: Color(0xFF2E9B58),
                    size: 36,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'تم إرسال الطلب بنجاح',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تم حفظ طلبك وإرساله إلى الصيدلية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: SearchUiColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: SearchUiColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'رقم الطلب',
                        style: TextStyle(
                          color: SearchUiColors.softText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        orderReference,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: SearchUiColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                const Text(
                  'احتفظ بهذا الرقم لمتابعة الطلب. الإرسال لا يمثل شراءً أو حجزًا نهائيًا للكميات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SearchUiColors.softText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SearchUiColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'متابعة الطلب',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _validateCurrentInventory() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _validateCurrentInventoryOnce();
      } on FirebaseException catch (error) {
        final retryable = {
          'unavailable',
          'deadline-exceeded',
          'unknown',
        }.contains(error.code);
        if (!retryable || attempt == 2) rethrow;
        debugPrint(
          'Inventory validation retry ${attempt + 2}/3: ${error.code}',
        );
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw StateError('تعذر التحقق من المخزون');
  }

  Future<String?> _validateCurrentInventoryOnce() async {
    final pharmacyDoc = await FirebaseFirestore.instance
        .collection('pharmacies')
        .doc(widget.pharmacy.id)
        .get();
    final pharmacyData = pharmacyDoc.data();
    if (!pharmacyDoc.exists ||
        pharmacyData == null ||
        !pharmacyAcceptsNewOrders(pharmacyData)) {
      return 'هذه الصيدلية غير متاحة لاستقبال الطلب حاليًا.';
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('medicine_search_index')
        .where('pharmacyId', isEqualTo: widget.pharmacy.id)
        .get();
    final byMedicineId = <String, Map<String, dynamic>>{
      for (final doc in snapshot.docs)
        (doc.data()['medicineId'] ?? doc.id).toString(): doc.data(),
    };

    for (final item in _selectedItems) {
      final current = byMedicineId[item.match.matchedMedicineId];
      final quote = current == null
          ? null
          : MedicineSaleQuote.fromIndex(
              current,
              soldByPiece: item.match.soldByPiece,
            );
      if (quote == null) {
        return 'لم يعد ${item.match.matchedMedicineName} متوفرًا؛ حدّث نتائج البحث.';
      }
      final available = quote.availableQuantity;
      if (available < item.quantity) {
        return 'الكمية المتاحة حاليًا من ${item.match.matchedMedicineName} هي $available فقط.';
      }
      final currentPrice = quote.price;
      if ((currentPrice - item.match.price).abs() > 0.001) {
        return 'تغير سعر ${item.match.matchedMedicineName}؛ حدّث نتائج البحث قبل الإرسال.';
      }
    }
    return null;
  }

  String get _insuranceLabel {
    return widget.useInsurance ? 'مع التأمين' : 'بدون تأمين';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final totalPieces = _selectedItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              const SizedBox(height: 7),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تأكيد الطلب',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: SearchUiColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderPartiesCard(),
                      const SizedBox(height: 10),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                              icon: Iconsax.box,
                              title: 'الأدوية المطلوبة',
                              trailing: _countBadge(_selectedItems.length),
                            ),
                            const SizedBox(height: 8),
                            if (_availableMedicines.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.18),
                                  ),
                                ),
                                child: const Text(
                                  'لا توجد أدوية متوفرة في هذه الصيدلية لإرسالها في الطلب.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              ...List.generate(_availableMedicines.length, (
                                index,
                              ) {
                                final item = _availableMedicines[index];

                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        index == _availableMedicines.length - 1
                                        ? 0
                                        : 7,
                                  ),
                                  child: _selectableMedicineTile(
                                    index: index + 1,
                                    item: item,
                                    onToggle: (value) {
                                      setState(() {
                                        item.isSelected = value;
                                        if (!item.isSelected) {
                                          item.quantity = 1;
                                        }
                                      });
                                    },
                                    onIncrease: () {
                                      setState(() {
                                        if (item.quantity < item.maxQuantity) {
                                          item.quantity++;
                                        }
                                      });
                                    },
                                    onDecrease: () {
                                      setState(() {
                                        if (item.quantity > 1) {
                                          item.quantity--;
                                        }
                                      });
                                    },
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildNotesTile(),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: SearchUiColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: SearchUiColors.primary.withOpacity(0.08),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Iconsax.info_circle,
                              color: SearchUiColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'السعر والتوفر تقديريان ويخضعان لمراجعة الصيدلية. إرسال الطلب لا يمثل شراءً أو حجزًا نهائيًا للكميات.',
                                style: TextStyle(
                                  height: 1.35,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: SearchUiColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_selectedItems.length} عنصر • $totalPieces قطعة',
                              style: const TextStyle(
                                color: SearchUiColors.softText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _selectedEstimatedTotal > 0
                                  ? '${_selectedEstimatedTotal.toStringAsFixed(2)} د.ل'
                                  : 'السعر غير محدد',
                              style: const TextStyle(
                                color: SearchUiColors.darkText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isSubmitting || !_hasSelectedMedicines)
                              ? null
                              : _submitOrder,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Iconsax.tick_circle, size: 19),
                          label: Text(
                            _isSubmitting ? 'جاري الإرسال...' : 'إرسال الطلب',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SearchUiColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(44),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderPartiesCard() {
    return _sectionCard(
      child: Column(
        children: [
          Row(
            children: [
              _compactIcon(Iconsax.hospital),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pharmacy.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SearchUiColors.darkText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.pharmacy.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SearchUiColors.softText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _compactLabel(widget.pharmacy.statusLabel),
              if (widget.pharmacy.distanceKm > 0) ...[
                const SizedBox(width: 5),
                _compactLabel(widget.pharmacy.displayDistance),
              ],
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              _compactIcon(
                widget.beneficiary.isSelf
                    ? Iconsax.profile_circle
                    : Iconsax.people,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.beneficiary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SearchUiColors.darkText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _compactLabel(_insuranceLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: SearchUiColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: SearchUiColors.primary, size: 17),
    );
  }

  Widget _compactLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: SearchUiColors.primary,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildNotesTile() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SearchUiColors.primary.withOpacity(0.08)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          leading: const Icon(
            Iconsax.note_2,
            color: SearchUiColors.primary,
            size: 19,
          ),
          title: const Text(
            'إضافة ملاحظة للصيدلية (اختياري)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          children: [
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'وقت الاستلام أو أي تفاصيل إضافية',
                hintStyle: const TextStyle(fontSize: 11.5),
                filled: true,
                fillColor: SearchUiColors.light,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SearchUiColors.primary.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: SearchUiColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: SearchUiColors.primary, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: SearchUiColors.primary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SearchUiColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: SearchUiColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _selectableMedicineTile({
    required int index,
    required _SelectableMedicineItem item,
    required ValueChanged<bool> onToggle,
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
  }) {
    final selected = item.isSelected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? SearchUiColors.light : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? SearchUiColors.primary.withOpacity(0.14)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: selected,
              onChanged: _isSubmitting
                  ? null
                  : (value) => onToggle(value ?? false),
              activeColor: SearchUiColors.primary,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: SearchUiColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.match.matchedMedicineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.match.estimatedPriceText} • الإجمالي ${(item.match.price * item.quantity).toStringAsFixed(2)} د.ل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SearchUiColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          _qtyButton(
            icon: Icons.remove,
            onTap: (_isSubmitting || !selected || item.quantity <= 1)
                ? null
                : onDecrease,
          ),
          SizedBox(
            width: 27,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SearchUiColors.darkText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _qtyButton(
            icon: Icons.add,
            onTap:
                (_isSubmitting ||
                    !selected ||
                    item.quantity >= item.maxQuantity)
                ? null
                : onIncrease,
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade200
              : SearchUiColors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey : SearchUiColors.primary,
        ),
      ),
    );
  }
}

class _SelectableMedicineItem {
  final MatchedMedicineResult match;
  bool isSelected = true;
  int quantity = 1;

  _SelectableMedicineItem({required this.match});

  int get maxQuantity => match.soldByPiece
      ? match.availablePieceQuantity
      : match.availableQuantity;
}

extension _MatchedMedicineUiX on MatchedMedicineResult {
  String get estimatedPriceText {
    if (price <= 0) return 'السعر غير محدد';
    return '${price.toStringAsFixed(2)} د.ل';
  }
}
