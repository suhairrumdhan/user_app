import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../chat/services/chat_service.dart';
import '../../chat/views/chat_detail_screen.dart';
import '../../search/views/search_ui_colors.dart';
import '../models/order_status.dart';
import '../widgets/offer_medicine_image.dart';
import '../models/pickup_time_remaining.dart';
import '../services/order_service.dart';

class OrderDetailsPage extends StatefulWidget {
  final OrderModel order;
  final Stream<OrderModel?>? orderUpdates;

  const OrderDetailsPage({super.key, required this.order, this.orderUpdates});

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
    _orderSubscription =
        (widget.orderUpdates ??
                OrderService.instance.watchOrderById(widget.order.id))
            .listen(
              (updatedOrder) {
                if (!mounted || updatedOrder == null) return;
                if (_order.updatedAt != null &&
                    updatedOrder.updatedAt != null &&
                    updatedOrder.updatedAt!.isBefore(_order.updatedAt!)) {
                  return;
                }
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
                    content: Text('تعذر تحديث الطلب. تحقق من الاتصال.'),
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
    final displayedTotal =
        order.currentCustomerTotalPrice ??
        (order.isAwaitingInsuranceRemoval
            ? null
            : order.medicines.fold<double>(
                0,
                (sum, item) => sum + item.lineTotal,
              ));
    final acceptedOffer =
        order.offerVersion > 0 &&
        order.acceptedOfferVersion == order.offerVersion;

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
                          order.containsInsurance
                              ? (order.status == OrderStatus.received
                                    ? 'بانتظار التحقق من التغطية'
                                    : 'شراء عن طريق التأمين')
                              : 'غير مستخدم',
                        ),
                        if (order.containsInsurance &&
                            order.insurance.companyName?.trim().isNotEmpty ==
                                true)
                          _row('شركة التأمين', order.insurance.companyName!),
                        if (order.containsInsurance &&
                            order.insurance.policyNumber?.trim().isNotEmpty ==
                                true)
                          _row(
                            'رقم وثيقة المستفيد',
                            order.insurance.policyNumber!,
                          ),
                      ],
                    ),
                    _section(
                      title:
                          acceptedOffer ||
                              order.status == OrderStatus.partialOfferPending
                          ? 'الأصناف الأصلية'
                          : 'الأدوية',
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
                        _row('عدد الأصناف', '${order.totalItemsCount}'),
                        _row(
                          order.isAwaitingInsuranceRemoval
                              ? 'السعر الحالي'
                              : order.status == OrderStatus.partialOfferPending
                              ? 'السعر الإجمالي'
                              : order.finalCustomerTotalPrice != null
                              ? 'السعر النهائي'
                              : acceptedOffer
                              ? 'سعر العرض المقبول'
                              : order.containsInsurance
                              ? 'المتبقي التقديري بعد التأمين'
                              : 'السعر التقديري',
                          displayedTotal != null
                              ? '${displayedTotal.toStringAsFixed(2)} د.ل'
                              : 'غير محدد',
                        ),
                        if (!order.isAwaitingInsuranceRemoval &&
                            order.finalInsuranceShare != null &&
                            order.finalInsuranceShare! > 0)
                          _row(
                            'حصة التأمين النهائية',
                            '${order.finalInsuranceShare!.toStringAsFixed(2)} د.ل',
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
    final waitingForCoverage = order.insuranceRemoval['status'] == 'pending';
    final deadline = waitingForCoverage ? null : order.pickupDeadline;
    final isOverdue = PickupTimeRemaining.isOverdue(
      isReady: !waitingForCoverage && order.status == OrderStatus.ready,
      serverMarkedOverdue: !waitingForCoverage && order.pickupOverdue,
      deadline: deadline,
      now: _now,
    );
    final accentColor = isOverdue ? Colors.deepOrange : SearchUiColors.primary;
    final displayedStatus = waitingForCoverage
        ? 'بانتظار قرار الدفع بدون تأمين'
        : isOverdue
        ? 'متأخر عن الاستلام'
        : order.displayStatusLabel;

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
              Icon(
                isOverdue ? Iconsax.warning_2 : Iconsax.info_circle,
                color: accentColor,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'الحالة: '),
                      TextSpan(
                        text: displayedStatus,
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
          if (deadline != null) ...[
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
                        _formatDateTime(deadline),
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
          ],
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
          if (order.status == OrderStatus.ready &&
              deadline != null &&
              !isOverdue) ...[
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepOrange.withValues(alpha: 0.45),
                  width: 1.4,
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconsax.danger, color: Colors.deepOrange, size: 22),
                  SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تأخر استلام الطلب',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'انتهت مهلة الاستلام. تواصل مع الصيدلية لمعرفة حالة الطلب.',
                          style: TextStyle(
                            color: Color(0xFF9A3412),
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.pharmacyDelayed) ...[
            const SizedBox(height: 9),
            const Text(
              'لم تراجع الصيدلية الطلب خلال 24 ساعة.',
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
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Iconsax.clock, color: SearchUiColors.primary),
        title: const Text(
          'سجل الطلب',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: SearchUiColors.primary,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        children: history.isEmpty
            ? [const Text('لا توجد تحديثات سابقة.', textAlign: TextAlign.right)]
            : history.map(_statusHistoryRow).toList(),
      ),
    );
  }

  Widget _statusHistoryRow(OrderStatusLog entry) {
    final parsedStatus = OrderStatusX.fromValue(entry.status);
    final label =
        parsedStatus == OrderStatus.unknown && entry.label.trim().isNotEmpty
        ? entry.label.trim()
        : parsedStatus.label;
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
          _row('الدواء', hasMatched ? matchedName : item.requestedName),
          _row('الكمية', '${item.quantity}'),
          _row(
            'سعر الوحدة عند الطلب',
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
        title: const Text('إلغاء الطلب؟'),
        content: const Text('لن تتمكن من التراجع بعد الإلغاء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('الاحتفاظ بالطلب'),
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
    } catch (_) {
      if (!mounted || !context.mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('تعذر فتح المحادثة. حاول مجددًا.'),
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

    if (!canCancel || (order.invoiceId?.isNotEmpty ?? false))
      return const SizedBox();

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
    final pending = order.status == OrderStatus.partialOfferPending;
    final accepted =
        order.offerVersion > 0 &&
        order.acceptedOfferVersion == order.offerVersion;
    if (!pending && !accepted) {
      return const SizedBox.shrink();
    }
    final rawItems = order.partialOffer['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final rawQuote = order.isAwaitingInsuranceRemoval
        ? order.insuranceRemoval['quote']
        : order.partialOffer['quote'];
    final quote = rawQuote is Map ? Map<String, dynamic>.from(rawQuote) : null;
    final rawQuotedItems = quote?['items'];
    final quotedItems = rawQuotedItems is List
        ? rawQuotedItems
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SearchUiColors.primary.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: SearchUiColors.primary,
                foregroundColor: Colors.white,
                child: Icon(Iconsax.receipt_item),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.isAwaitingInsuranceRemoval
                          ? 'الأصناف — المبلغ الجديد بانتظار موافقتك'
                          : pending
                          ? (order.partialOffer['kind'] == 'replacement'
                                ? 'عرض تبديل الأصناف'
                                : order.partialOffer['kind'] == 'full'
                                ? 'عرض سعر الطلب'
                                : 'عرض من الصيدلية')
                          : 'العرض الذي وافقت عليه',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      pending
                          ? 'راجع الأصناف والسعر قبل القبول'
                          : 'الأصناف والكميات المعتمدة',
                      style: const TextStyle(color: SearchUiColors.softText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 4),
          if (order.partialOffer['kind'] == 'replacement')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${order.partialOffer['reason'] ?? ''}'),
            ),
          if (items.isEmpty)
            const Text('تعذر عرض تفاصيل الأصناف. حدّث الصفحة وحاول مجددًا.')
          else
            ...items.map((item) => _partialOfferItem(item, quotedItems)),
          if (quote != null) ...[
            const Divider(),
            if (pending && order.estimatedTotalPrice != null)
              _row(
                'السعر السابق',
                '${order.estimatedTotalPrice!.toStringAsFixed(2)} د.ل',
              ),
            if ((_offerPrice(quote['insuranceShare']) ?? 0) > 0) ...[
              _row('إجمالي الأصناف', _offerMoney(quote['grossTotal'])),
              _row('حصة التأمين', _offerMoney(quote['insuranceShare'])),
            ],
            _row(
              (_offerPrice(quote['insuranceShare']) ?? 0) > 0
                  ? 'الإجمالي بعد التأمين'
                  : 'السعر الإجمالي',
              _offerMoney(quote['customerTotal']),
            ),
          ] else if (pending)
            const Text('السعر غير متوفر. اطلب عرضًا جديدًا من الصيدلية.'),
          if (pending && order.userDecisionDeadline != null) ...[
            const SizedBox(height: 6),
            Text(
              'الرد قبل: ${_formatDateTime(order.userDecisionDeadline!)}',
              style: const TextStyle(
                color: SearchUiColors.softText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (pending && unavailable) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'الكمية لم تعد متاحة. حاول لاحقًا أو تواصل مع الصيدلية.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (pending) const SizedBox(height: 12),
          if (pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isDecidingOffer ||
                            items.isEmpty ||
                            quote == null ||
                            order.insuranceRemoval['status'] == 'pending' ||
                            order.offerVersion < 1
                        ? null
                        : () => _decideOffer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SearchUiColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                    onPressed:
                        _isDecidingOffer ||
                            ((order.invoiceId?.isNotEmpty ?? false) &&
                                order.isAwaitingInsuranceRemoval)
                        ? null
                        : () => _decideOffer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SearchUiColors.danger,
                      side: BorderSide(
                        color: SearchUiColors.danger.withValues(alpha: .35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Iconsax.close_circle),
                    label: Text(
                      (order.invoiceId?.isNotEmpty ?? false)
                          ? 'رفض التبديل'
                          : 'رفض العرض وإلغاء الطلب',
                    ),
                  ),
                ),
              ],
            ),
          if (pending) const SizedBox(height: 7),
          if (pending)
            const Text(
              'يتم الحجز بعد قبول العرض.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _partialOfferItem(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> quotedItems,
  ) {
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
    final quoted = quotedItems
        .where(
          (line) =>
              '${line['medicineId']}' == medicineId &&
              (line['soldByPiece'] == true) == soldByPiece,
        )
        .firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        border: Border.all(
          color: SearchUiColors.primary.withValues(alpha: .12),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              OfferMedicineImage(
                url:
                    item['imageUrl']?.toString() ?? matchingOrderItem?.imageUrl,
                name: name,
              ),
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
          if (item['isReplacement'] == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                OfferMedicineImage(
                  url: item['originalImageUrl']?.toString(),
                  name: '${item['originalMedicineName'] ?? ''}',
                  size: 40,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'بدلاً من ${item['originalMedicineName'] ?? ''} • ${item['originalQuantity']} ${item['replacesSoldByPiece'] == true ? 'قطعة' : 'علبة'}',
                    style: const TextStyle(color: SearchUiColors.softText),
                  ),
                ),
              ],
            ),
          ],
          if (quoted != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'سعر الوحدة ${_offerMoney(quoted['unitPrice'])} • الإجمالي ${_offerMoney((_offerPrice(quoted['unitPrice']) ?? 0) * quantity)}',
              ),
            ),
        ],
      ),
    );
  }

  double? _offerPrice(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  String _offerMoney(dynamic value) {
    final price = _offerPrice(value);
    return price == null ? 'غير محدد' : '${price.toStringAsFixed(2)} د.ل';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $hour:$minute';
  }

  Widget _buildInsuranceDecisionAction() {
    if (!order.insurance.enabled ||
        ![
          OrderStatus.received,
          OrderStatus.underReview,
          OrderStatus.partialOfferPending,
          OrderStatus.confirmedReserved,
          OrderStatus.preparing,
          OrderStatus.ready,
        ].contains(order.status)) {
      return const SizedBox.shrink();
    }
    final reasons = (order.insuranceResolution['reasons'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => '${item['message'] ?? ''}'.trim())
        .where((message) => message.isNotEmpty)
        .toList();
    final removal = order.insuranceRemoval;
    if (removal['status'] == 'pending') {
      final quote = Map<String, dynamic>.from(removal['quote'] as Map);
      final version = (removal['version'] as num).toInt();
      return _section(
        title: 'الدفع بدون تأمين',
        icon: Iconsax.shield_cross,
        children: [
          const Text('هل ترغب بالمتابعة؟'),
          if (order.status == OrderStatus.received)
            ...reasons.map((message) => Text(message)),
          if ('${removal['reason'] ?? ''}'.trim().isNotEmpty)
            Text('السبب: ${removal['reason']}'),
          _row('السعر السابق', _offerMoney(quote['previousCustomerTotal'])),
          _row('السعر الحالي', _offerMoney(quote['customerTotal'])),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton(
                onPressed: _isResolvingInsurance
                    ? null
                    : () => _insuranceRemovalDecision(version, true),
                child: const Text('متابعة'),
              ),
              TextButton(
                onPressed: _isResolvingInsurance
                    ? null
                    : () => _insuranceRemovalDecision(version, false),
                child: const Text('إلغاء الطلب'),
              ),
            ],
          ),
          TextButton(
            onPressed: _isResolvingInsurance
                ? null
                : () => _refreshInsuranceAmount(version),
            child: const Text('تحديث السعر'),
          ),
        ],
      );
    }
    final quoteButton = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: _isResolvingInsurance
            ? null
            : () async {
                setState(() => _isResolvingInsurance = true);
                try {
                  await OrderService.instance.requestInsuranceRemoval(
                    orderId: order.id,
                  );
                  await _syncOrderFromServer();
                  if (!mounted) return;
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(content: Text('راجع السعر الحالي')),
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
          _isResolvingInsurance
              ? 'جاري حساب المبلغ...'
              : 'عرض السعر بدون تأمين',
        ),
      ),
    );
    if (order.status != OrderStatus.received) return quoteButton;
    return _section(
      title: 'تعذر اعتماد التأمين',
      icon: Iconsax.shield_cross,
      children: [
        if (reasons.isEmpty)
          const Text('تعذر التحقق من التغطية التأمينية لهذا الطلب.')
        else
          ...reasons.map((message) => Text(message)),
        const Text('يمكنك المتابعة بدون تأمين أو الإلغاء.'),
        quoteButton,
        TextButton(
          onPressed: _isCancelling ? null : () => _cancelOrder(context),
          child: const Text('إلغاء الطلب'),
        ),
      ],
    );
  }

  Future<void> _insuranceRemovalDecision(int version, bool accept) async {
    if (_isResolvingInsurance) return;
    setState(() => _isResolvingInsurance = true);
    try {
      await OrderService.instance.decideInsuranceRemoval(
        orderId: order.id,
        version: version,
        accept: accept,
      );
      await _syncOrderFromServer();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'تم اعتماد الدفع بدون تأمين' : 'تم إلغاء الطلب',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            error.toString().contains('stale-offer-price')
                ? 'تغيّر السعر. حدّثه قبل المتابعة.'
                : 'تعذر حفظ اختيارك. حدّث الطلب وأعد المحاولة.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolvingInsurance = false);
    }
  }

  Future<void> _refreshInsuranceAmount(int version) async {
    if (_isResolvingInsurance) return;
    setState(() => _isResolvingInsurance = true);
    try {
      await OrderService.instance.requestInsuranceRemoval(
        orderId: order.id,
        version: version,
      );
      await _syncOrderFromServer();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث السعر. حدّث الطلب ثم حاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolvingInsurance = false);
    }
  }

  Future<void> _syncOrderFromServer() async {
    try {
      final latest = await OrderService.instance.getOrderById(
        order.id,
        fromServer: true,
      );
      if (!mounted || latest == null) return;
      setState(() {
        _order = latest;
        _now = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال القرار، لكن تعذر جلب أحدث حالة. تحقق من الاتصال.',
            ),
          ),
        );
      }
    }
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
      await _syncOrderFromServer();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'تم قبول العرض وحجز الكمية المتاحة'
                : order.status == OrderStatus.cancelled
                ? 'تم رفض العرض وإلغاء الطلب'
                : 'تم رفض التبديل؛ الطلب الأصلي مستمر',
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
      return 'الكمية لم تعد متاحة. حاول لاحقًا أو تواصل مع الصيدلية.';
    }
    if (value.contains('stale-offer-price')) {
      return 'تغير السعر. اطلب عرضًا جديدًا من الصيدلية.';
    }
    if (value.contains('stale-offer-version') ||
        value.contains('partial offer changed')) {
      return 'تغير العرض. راجع أحدث عرض من الصيدلية قبل القبول.';
    }
    if (value.contains('unauthenticated') ||
        value.contains('permission-denied')) {
      return 'سجّل الدخول ثم حاول مجددًا.';
    }
    if (value.contains('unavailable') || value.contains('deadline-exceeded')) {
      return 'تعذر الاتصال. تحقق من الإنترنت وحاول مجددًا.';
    }
    return 'تعذر تنفيذ القرار. حاول مجددًا.';
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
      )?.showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('تعذر إلغاء الطلب. حاول مجددًا.')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }
}
