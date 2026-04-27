import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/insurance_controller.dart';
import '../models/insurance_model.dart';
import 'add_edit_insurance_page.dart';

class InsurancePage extends StatelessWidget {
  InsurancePage({super.key});

  final InsuranceController controller = Get.isRegistered<InsuranceController>()
      ? Get.find<InsuranceController>()
      : Get.put(InsuranceController());

  final Color pPrimaryColor = const Color(0xFF5EABD6);
  final Color pSecondaryColor = const Color(0xFF7BC4EA);
  final Color pLightColor = const Color(0xFFF5FBFF);
  final Color pAccentColor = const Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pPrimaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "التأمين الصحي",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),

                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const AddEditInsurancePage());
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Iconsax.add,
                        color: pPrimaryColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: StreamBuilder<List<InsuranceModel>>(
                  stream: controller.getInsurances(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF5EABD6),
                          ),
                        ),
                      );
                    }

                    final insurances = snapshot.data!;

                    if (insurances.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildTopCard(),
                        const SizedBox(height: 18),
                        ...insurances.map(
                              (insurance) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildInsuranceCard(insurance, context),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pPrimaryColor, pSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pPrimaryColor.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Iconsax.shield_tick,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة شركات التأمين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'أضيفي شركات التأمين الخاصة بك وحددي فترة التغطية والأشخاص المشمولين بها.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTopCard(),
          const SizedBox(height: 40),
          Icon(
            Iconsax.shield_cross,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "لا توجد شركات تأمين",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "أضيفي شركة التأمين الخاصة بك الآن",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Get.to(() => const AddEditInsurancePage());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("إضافة شركة تأمين"),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceCard(
      InsuranceModel insurance,
      BuildContext context,
      ) {
    final bool isActive = insurance.isActive;

    return Container(
      width: double.infinity,
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
          color: isActive
              ? pAccentColor.withOpacity(0.20)
              : Colors.red.withOpacity(0.14),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isActive
                      ? pAccentColor.withOpacity(0.12)
                      : Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isActive ? Iconsax.shield_tick : Iconsax.shield_slash,
                  color: isActive ? pAccentColor : Colors.redAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insurance.companyName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? pAccentColor.withOpacity(0.10)
                            : Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'ساري' : 'منتهي',
                        style: TextStyle(
                          color: isActive ? pAccentColor : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Get.to(
                          () => AddEditInsurancePage(
                        insuranceId: insurance.id,
                      ),
                    );
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, insurance);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('تعديل'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildInfoRow(
            icon: Iconsax.code,
            title: 'كود الشركة',
            value: insurance.companyCode,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Iconsax.card,
            title: 'رقم البطاقة',
            value: insurance.cardNumber,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniInfoBox(
                  icon: Iconsax.calendar_1,
                  title: 'بداية التغطية',
                  value: _formatDate(insurance.startDate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniInfoBox(
                  icon: Iconsax.calendar_remove,
                  title: 'نهاية التغطية',
                  value: _formatDate(insurance.endDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Iconsax.profile_2user,
            title: 'عدد المشمولين',
            value: '${insurance.coveredMemberIds.length} أشخاص',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pPrimaryColor.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: pPrimaryColor, size: 20),
          const SizedBox(width: 10),
          Text(
            '$title: ',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pLightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pPrimaryColor.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: pPrimaryColor, size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, InsuranceModel insurance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("حذف شركة التأمين"),
        content: Text("هل أنت متأكد من حذف ${insurance.companyName}؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteInsurance(insurance.id);
            },
            child: const Text(
              "حذف",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.year}/${date.month}/${date.day}';
  }
}