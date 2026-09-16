import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../chat/services/chat_service.dart';
import '../../chat/views/chat_detail_screen.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';
import '../models/pickup_time_remaining.dart';
import '../services/order_service.dart';

class OrderDetailsPage extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isOpeningChat = false;
  bool _isCancelling = false;
  bool _isDecidingOffer = false;
  bool _isResolvingInsurance = false;
  int? _unavailableOfferVersion;
  StreamSubscription<OrderModel?>? _orderSubscription;
  late final Timer _pickupTicker;
  late OrderModel _order;
  DateTime _now = DateTime.now();

  OrderModel get order => _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _pickupTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          _order.status != OrderStatus.ready ||
          _order.pickupDeadline == null) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
    _orderSubscription = OrderService.instance
        .watchOrderById(widget.order.id)
        .listen(
          (updatedOrder) {
            if (!mounted || updatedOrder == null) return;
            setState(() {
              if (updatedOrder.offerVersion != _order.offerVersion) {
                _unavailableOfferVersion = null;
              }
              _order = updatedOrder;
              _now = DateTime.now();
            });
          },
          onError: (Object error) {
            debugPrint('Order details stream failed: $error');
            if (!mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'تعذر تحديث حالة الطلب. تحقق من الاتصال وأعد فتح الطلب.',
                ),
              ),
            );
          },
        );
  }

  @override
  void dispose() {
    _pickupTicker.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimatedTotal =
        order.estimatedTotalPrice ??
        order.medicines.fold<double>(0, (sum, item) => sum + item.lineTotal);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SearchUiColors.primary,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'تفاصيل الطلب',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: SearchUiColors.light,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _orderStatusCard(),
                    _statusHistoryCard(),
                    _section(
                      title: 'الصيدلية',
                      icon: Iconsax.hospital,
                      children: [
                        _row('الاسم', order.pharmacy.pharmacyName),
                        _row('العنوان', order.pharmacy.address ?? 'غير متوفر'),
                        if (order.pharmacy.distanceKm != null)
                          _row(
                            'المسافة',
                            '${order.pharmacy.distanceKm!.toStringAsFixed(1)} كم',
                          ),
                      ],
                    ),
                    _section(
                      title: 'المستفيد',
                      icon: Iconsax.profile_circle,
                      children: [
                        _row('الاسم', order.beneficiary.name),
                        _row(
                          'التأمين',
                          order.containsInsurance ? 'متضمن' : 'غير متضمن',
                        ),
                      ],
                    ),
                    _section(
                      title: 'الأدوية',
                      icon: Iconsax.box,
                      children: order.medicines
                          .map((e) => _medicineRow(e))
                          .toList(),
                    ),
                    _section(
                      title: 'ملخص الطلب',
                      icon: Iconsax.timer_1,
                      children: [
                        _row('رقم الطلب', _orderReference),
                        _row('عدد العناصر', '${order.totalItemsCount}'),
                        _row(
                          'السعر ',
                          estimatedTotal > 0
                              ? '${estimatedTotal.toStringAsFixed(2)} د.ل'
                              : 'غير محدد',
                        ),
                        if (order.userNote?.trim().isNotEmpty == true)
                          _row('ملاحظاتك', order.userNote!.trim()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInsuranceDecisionAction(),
                    _buildPartialOfferCard(),
                    _buildChatButton(context),
                    _buildCancelButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _orderReference {
    final orderNumber = order.orderNumber?.trim();
    return orderNumber != null && orderNumber.isNotEmpty
        ? orderNumber
        : order.id;
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: SearchUiColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: SearchUiColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderStatusCard() {
    final deadline = order.pickupDeadline;
    final isOverdue = PickupTimeRemaining.isOverdue(
      isReady: order.status == OrderStatus.ready,
      serverMarkedOverdue: order.pickupOverdue,
      deadline: deadline,
      now: _now,
    );
    final accentColor = isOverdue ? Colors.deepOrange : SearchUiColors.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.info_circle, color: accentColor, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'الحالة: '),
                      TextSpan(
                        text: order.status.label,
                        style: TextStyle(color: accentColor),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 9),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.calendar_tick, color: accentColor, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آخر موعد للاستلام',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deadline == null
                          ? 'يُحدَّد عند جاهزية الطلب للاستلام'
                          : _formatDateTime(deadline),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (order.readyAt != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Divider(height: 1),
            ),
            _pickupFact(
              icon: Iconsax.timer_1,
              title: 'وقت جاهزية الطلب',
              value: _formatDateTime(order.readyAt!),
              color: accentColor,
            ),
          ],
          if (order.status == OrderStatus.ready && deadline != null) ...[
            const SizedBox(height: 10),
            Text(
              PickupTimeRemaining.format(deadline: deadline, now: _now)!,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (isOverdue) ...[
            const SizedBox(height: 9),
            const Text(
              'تجاوزت مهلة الاستلام. طلبك ما زال جاهزًا؛ تواصل مع الصيدلية.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (order.pharmacyDelayed) ...[
            const SizedBox(height: 9),
            const Text(
              'تجاوزت مدة معالجة الصيدلية 24 ساعة دون احتساب انتظار قرارك.',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pickupFact({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusHistoryCard() {
    final history = order.statusHistory;
    return _section(
      title: 'سجل حالات الطلب',
      icon: Iconsax.clock,
      children: history.isEmpty
          ? [
              const Text(
                'لا يتوفر سجل للحالات لهذا الطلب.',
                textAlign: TextAlign.right,
              ),
            ]
          : history.map(_statusHistoryRow).toList(),
    );
  }

  Widget _statusHistoryRow(OrderStatusLog entry) {
    final label = entry.label.trim().isNotEmpty
        ? entry.label.trim()
        : OrderStatusX.fromValue(entry.status).label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Iconsax.tick_circle,
            color: SearchUiColors.primary,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.changedAt == null
                      ? 'وقت التغيير غير متوفر'
                      : _formatDateTime(entry.changedAt!),
                  style: const TextStyle(
                    color: SearchUiColors.softText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicineRow(OrderMedicineItem item) {
    final matchedName = item.matchedMedicineName?.trim();
    final hasMatched = matchedName != null && matchedName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SearchUiColors.primary.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          if (hasMatched) _row(' العنصر', matchedName),
          _row('الكمية', '${item.quantity}'),
          _row(
            'السعر',
            item.estimatedPrice != null && item.estimatedPrice! > 0
                ? '${item.estimatedPrice!.toStringAsFixed(2)} د.ل'
                : 'غير محدد',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تأكيد الإلغاء'),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا الطلب؟',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _cancelOrder(context);
    }
  }

  Widget _buildChatButton(BuildContext context) {
    final chatClosed =
        order.status == OrderStatus.completed ||
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.rejected ||
        order.status == OrderStatus.notCollected;
    if (chatClosed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      child: ElevatedButton.icon(
        onPressed: order.id.trim().isEmpty || _isOpeningChat
            ? null
            : () => _openChat(context),
        icon: _isOpeningChat
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Iconsax.messages),
        label: Text(
          _isOpeningChat ? 'جاري فتح المحادثة...' : 'محادثة الصيدلية',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: SearchUiColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: SearchUiColors.primary.withOpacity(0.55),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    if (_isOpeningChat) return;

    setState(() => _isOpeningChat = true);

    try {
      final thread = await ChatService.instance.getOrCreateOrderChat(order);

      if (!mounted) return;
      setState(() => _isOpeningChat = false);

      Get.to(() => ChatDetailScreen(thread: thread));
    } catch (e) {
      if (!mounted || !context.mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'تعذر فتح المحادثة: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted && _isOpeningChat) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  Widget _buildCancelButton(BuildContext context) {
    final canCancel = order.status.canTransitionTo(
      OrderStatus.cancelled,
      actorType: 'user',
    );

    if (!canCancel) return const SizedBox();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      child: ElevatedButton.icon(
        onPressed: _isCancelling ? null : () => _confirmCancel(context),
        icon: _isCancelling
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Iconsax.close_circle),
        label: Text(_isCancelling ? 'جاري الإلغاء...' : 'إلغاء الطلب'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildPartialOfferCard() {
    if (order.status != OrderStatus.partialOfferPending) {
      return const SizedBox.shrink();
    }
    final rawItems = order.partialOffer['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final unavailable = _unavailableOfferVersion == order.offerVersion;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF8A3D), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFF8A3D),
                foregroundColor: Colors.white,
                child: Icon(Iconsax.receipt_item),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'عرض جزئي يحتاج قرارك',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'النسخة الحالية: ${order.offerVersion}',
                      style: const TextStyle(
                        color: Color(0xFF9A4B17),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'الصيدلية وفّرت الأصناف التالية فقط:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          if (items.isEmpty)
            const Text('تعذر عرض تفاصيل الأصناف. حدّث الصفحة وحاول مجددًا.')
          else
            ...items.map(_partialOfferItem),
          if (order.userDecisionDeadline != null) ...[
            const SizedBox(height: 6),
            Text(
              'المهلة حتى: ${_formatDateTime(order.userDecisionDeadline!)}',
              style: const TextStyle(
                color: Color(0xFF9A4B17),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (unavailable) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'الكمية المتاحة للحجز غير كافية حاليًا. يمكنك إعادة المحاولة بعد توفرها، أو التواصل مع الصيدلية لتعديل العرض.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isDecidingOffer ||
                          items.isEmpty ||
                          order.offerVersion < 1
                      ? null
                      : () => _decideOffer(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Iconsax.tick_circle),
                  label: Text(
                    _isDecidingOffer
                        ? 'جاري التنفيذ...'
                        : unavailable
                        ? 'إعادة محاولة القبول'
                        : 'قبول العرض',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDecidingOffer
                      ? null
                      : () => _decideOffer(false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Iconsax.close_circle),
                  label: const Text('رفض العرض'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'لن يُحجز أي دواء إلا بعد قبولك لهذه النسخة.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _partialOfferItem(Map<String, dynamic> item) {
    final medicineId = (item['medicineId'] ?? item['matchedMedicineId'] ?? '')
        .toString();
    final matchingOrderItem = order.medicines
        .cast<OrderMedicineItem?>()
        .firstWhere(
          (medicine) => medicine?.matchedMedicineId == medicineId,
          orElse: () => null,
        );
    final name =
        (item['medicineName'] ??
                item['matchedMedicineName'] ??
                item['name'] ??
                matchingOrderItem?.matchedMedicineName ??
                matchingOrderItem?.requestedName ??
                'دواء')
            .toString();
    final quantity = int.tryParse('${item['quantity']}') ?? 0;
    final soldByPiece =
        item['soldByPiece'] == true || item['sellAsPiece'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.box_tick, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$quantity ${soldByPiece ? 'قطعة' : 'علبة'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hour:$minute';
  }

  Widget _buildInsuranceDecisionAction() {
    if (order.status != OrderStatus.received || !order.containsInsurance) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: _isResolvingInsurance
            ? null
            : () async {
                setState(() => _isResolvingInsurance = true);
                try {
                  await OrderService.instance.continueWithoutInsurance(
                    orderId: order.id,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تمت متابعة الطلب دون تأمين وبدأت مراجعة الصيدلية',
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تعذر متابعة الطلب. تحقق من الاتصال وحاول مجددًا.',
                      ),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isResolvingInsurance = false);
                }
              },
        icon: const Icon(Iconsax.shield_cross),
        label: Text(
          _isResolvingInsurance ? 'جاري المتابعة...' : 'متابعة الطلب دون تأمين',
        ),
      ),
    );
  }

  Future<void> _decideOffer(bool accept) async {
    if (_isDecidingOffer) return;
    final submittedOrderId = order.id;
    final submittedVersion = order.offerVersion;
    setState(() => _isDecidingOffer = true);
    try {
      if (accept) {
        await OrderService.instance.acceptPartialOffer(
          orderId: submittedOrderId,
          offerVersion: submittedVersion,
        );
      } else {
        await OrderService.instance.rejectPartialOffer(
          orderId: submittedOrderId,
          offerVersion: submittedVersion,
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'تم قبول العرض وحجز الكمية المتاحة' : 'تم رفض العرض',
          ),
          backgroundColor: accept ? Colors.green : Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _offerDecisionError(error);
      if (accept &&
          _isUnavailableOfferError(error) &&
          order.offerVersion == submittedVersion) {
        setState(() => _unavailableOfferVersion = submittedVersion);
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDecidingOffer = false);
    }
  }

  bool _isUnavailableOfferError(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('insufficient stock') ||
        value.contains('inactive or expired') ||
        value.contains('reserved medicine is missing');
  }

  String _offerDecisionError(Object error) {
    final value = error.toString().toLowerCase();
    if (_isUnavailableOfferError(error)) {
      return 'تعذر قبول العرض: الكمية المتاحة للحجز غير كافية، أو الدواء غير صالح للبيع. تواصل مع الصيدلية أو أعد المحاولة بعد توفره.';
    }
    if (value.contains('stale-offer-version') ||
        value.contains('partial offer changed')) {
      return 'قامت الصيدلية بتحديث العرض. راجع النسخة الجديدة قبل القبول.';
    }
    if (value.contains('unauthenticated') ||
        value.contains('permission-denied')) {
      return 'انتهت جلسة الدخول أو لا توجد صلاحية. سجّل الدخول ثم حاول مجددًا.';
    }
    if (value.contains('unavailable') || value.contains('deadline-exceeded')) {
      return 'تعذر الاتصال بالخادم حاليًا. تحقق من الإنترنت ثم حاول مجددًا.';
    }
    return 'تعذر تنفيذ قرار العرض. حاول مجددًا أو تواصل مع الصيدلية.';
  }

  Future<void> _cancelOrder(BuildContext context) async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await OrderService.instance.updateOrderStatus(
        orderId: order.id,
        newStatus: OrderStatus.cancelled,
        changedById: order.user.userId,
        changedByType: 'user',
        note: 'تم إلغاء الطلب من قبل المستخدم',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب بنجاح')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('فشل في إلغاء الطلب. تحقق من الاتصال وحاول مجددًا.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}
