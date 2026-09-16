import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../models/beneficiary_model.dart';

class BeneficiarySelectionResult {
  final BeneficiaryModel beneficiary;
  final bool savePrescription;

  const BeneficiarySelectionResult({
    required this.beneficiary,
    required this.savePrescription,
  });
}

class BeneficiarySelectorSheet extends StatefulWidget {
  final List<BeneficiaryModel> beneficiaries;
  final ValueChanged<BeneficiarySelectionResult>? onSelected;
  final bool showSaveOption;
  final bool initialSaveValue;
  final String title;
  final String subtitle;

  const BeneficiarySelectorSheet({
    super.key,
    required this.beneficiaries,
    this.onSelected,
    this.showSaveOption = true,
    this.initialSaveValue = false,
    this.title = 'اختيار المستفيد',
    this.subtitle = 'اختر الشخص الذي تخصه الوصفة أو الطلب',
  });

  @override
  State<BeneficiarySelectorSheet> createState() =>
      _BeneficiarySelectorSheetState();
}

class _BeneficiarySelectorSheetState extends State<BeneficiarySelectorSheet> {
  static const Color primary = Color(0xFF5EABD6);
  static const Color secondary = Color(0xFF7BC4EA);
  static const Color light = Color(0xFFF5FBFF);

  late bool _savePrescription;

  @override
  void initState() {
    super.initState();
    _savePrescription = widget.initialSaveValue;
  }

  void _selectBeneficiary(BeneficiaryModel beneficiary) {
    final result = BeneficiarySelectionResult(
      beneficiary: beneficiary,
      savePrescription: _savePrescription,
    );

    Navigator.pop(context, result);
    widget.onSelected?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    ...widget.beneficiaries.map(_buildBeneficiaryItem),
                    if (widget.showSaveOption) ...[
                      const SizedBox(height: 6),
                      _buildSavePrescriptionCard(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Iconsax.profile_2user, color: primary),
        const SizedBox(width: 8),
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBeneficiaryItem(BeneficiaryModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectBeneficiary(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: light,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primary.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withOpacity(0.16),
                      secondary.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.isSelf ? Iconsax.profile_circle : Iconsax.people,
                  color: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Iconsax.arrow_left_2, color: primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavePrescriptionCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _savePrescription = !_savePrescription;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _savePrescription ? primary.withOpacity(0.08) : light,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _savePrescription
                ? primary.withOpacity(0.35)
                : primary.withOpacity(0.12),
            width: _savePrescription ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _savePrescription
                    ? primary.withOpacity(0.16)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _savePrescription ? Iconsax.save_2 : Iconsax.archive_add,
                color: primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حفظ هذه الوصفة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'سيتم حفظ الأدوية مع المستفيد، ومع الملف الأصلي إذا كانت الوصفة مرفقة.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: _savePrescription,
              activeColor: primary,
              onChanged: (value) {
                setState(() {
                  _savePrescription = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
