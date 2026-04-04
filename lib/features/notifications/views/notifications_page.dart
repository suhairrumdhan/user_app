import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'طلبك جاهز للاستلام',
      message: 'يمكنك استلام الوصفة الطبية من صيدلية النور - فرع المدينة المنورة',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      type: NotificationType.order,
      isRead: false,
      icon: Icons.medical_services_outlined,
      iconColor: Colors.green,
      gradient: [const Color(0xFF00B894), const Color(0xFF00D4A4)],
    ),
    NotificationItem(
      id: '2',
      title: 'عرض خاص 🎉',
      message: 'خصم 20% على جميع المستحضرات الطبية هذا الأسبوع في صيدلية الحياة',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.promotion,
      isRead: false,
      icon: Icons.local_offer_outlined,
      iconColor: Colors.orange,
      gradient: [const Color(0xFFFF9F43), const Color(0xFFFFB84D)],
    ),
    NotificationItem(
      id: '3',
      title: 'تذكير بالموعد الطبي',
      message: 'موعدك مع د. أحمد محمد غداً الساعة 10:00 صباحاً',
      time: DateTime.now().subtract(const Duration(hours: 5)),
      type: NotificationType.reminder,
      isRead: true,
      icon: Icons.calendar_month_outlined,
      iconColor: Colors.blue,
      gradient: [const Color(0xFF546DE5), const Color(0xFF6C8AEC)],
    ),
    NotificationItem(
      id: '4',
      title: 'وصفة طبية جديدة',
      message: 'تم إضافة وصفة طبية جديدة إلى سجلك الشخصي',
      time: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.prescription,
      isRead: true,
      icon: Icons.description_outlined,
      iconColor: Colors.purple,
      gradient: [const Color(0xFFA55EEA), const Color(0xFFB87BED)],
    ),
    NotificationItem(
      id: '5',
      title: 'صيدلية جديدة بالقرب منك',
      message: 'صيدلية الورد افتتحت فرع جديد في منطقتك',
      time: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.nearby,
      isRead: true,
      icon: Icons.location_on_outlined,
      iconColor: Colors.red,
      gradient: [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)],
    ),
  ];

  final Color _primaryColor = const Color(0xFF5EABD6);
  final Color _backgroundColor = const Color(0xFFF8FAFD);

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
    _showSnackBar('تم تعيين جميع الإشعارات كمقروءة', Colors.green);
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((notification) => notification.id == id);
    });
  }

  void _clearAllNotifications() {
    setState(() {
      _notifications.clear();
    });
    _showSnackBar('تم مسح جميع الإشعارات', Colors.green);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    final bool isTablet = screenWidth > 600;
    final bool isSmallScreen = screenWidth < 350;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Column(
        children: [
          // 🔹 Modern Header with Gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  _primaryColor,
                  const Color(0xFF6FB9E3),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 24,
                  vertical: isTablet ? 20 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 App Bar
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: isTablet ? 24 : 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'الإشعارات',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: isTablet ? 28 : 24,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        if (_notifications.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'mark_all_read') _markAllAsRead();
                                if (value == 'clear_all') _clearAllNotifications();
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'mark_all_read',
                                  child: Row(
                                    children: [
                                      Icon(Icons.mark_email_read,
                                          color: Colors.blue, size: isTablet ? 22 : 18),
                                      SizedBox(width: isTablet ? 12 : 8),
                                      Text(
                                        'تعيين الكل كمقروء',
                                        style: TextStyle(fontSize: isTablet ? 16 : 14),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'clear_all',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_sweep_rounded,
                                          color: Colors.red, size: isTablet ? 22 : 18),
                                      SizedBox(width: isTablet ? 12 : 8),
                                      Text(
                                        'مسح الكل',
                                        style: TextStyle(fontSize: isTablet ? 16 : 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(Icons.more_vert_rounded,
                                    color: Colors.white, size: isTablet ? 24 : 20),
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),

                    // 🔹 Stats Cards
                    Row(
                      children: [
                        _buildStatCard(
                          'الإجمالي',
                          _notifications.length.toString(),
                          Icons.notifications_active_rounded,
                          Colors.blueGrey.withValues(alpha: 0.6),
                          isTablet,
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        _buildStatCard(
                          'غير مقروء',
                          _notifications.where((n) => !n.isRead).length.toString(),
                          Icons.mark_email_unread_rounded,
                          Colors.pink.shade700.withValues(alpha: 0.9),
                          isTablet,
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 30 : 20),
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Notifications List
          Expanded(
            child: _notifications.isEmpty
                ? _buildEmptyState(isTablet)
                : Container(
              padding: EdgeInsets.only(
                top: isTablet ? 24 : 16,
                left: isTablet ? 20 : 16,
                right: isTablet ? 20 : 16,
              ),
              child: Column(
                children: [
                  // 🔹 Recent Notifications Title
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 8 : 4),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            color: _primaryColor, size: isTablet ? 20 : 16),
                        SizedBox(width: isTablet ? 8 : 6),
                        Text(
                          'الإشعارات الحديثة',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_notifications.length} عنصر',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isTablet ? 16 : 12),

                  // 🔹 Notifications List
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.only(bottom: isTablet ? 100 : 80),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: isTablet ? 12 : 8),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _NotificationCard(
                          notification: notification,
                          onDismissed: () => _deleteNotification(notification.id),
                          onTap: () {
                            setState(() {
                              notification.isRead = true;
                            });
                          },
                          primaryColor: _primaryColor,
                          isTablet: isTablet,
                          isSmallScreen: isSmallScreen,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isTablet) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: isTablet ? 28 : 22),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: isTablet ? 4 : 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 50 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Animated Empty State
            Container(
              width: isTablet ? 180 : 120,
              height: isTablet ? 180 : 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryColor.withOpacity(0.1),
                    _primaryColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: isTablet ? 70 : 50,
                color: _primaryColor.withOpacity(0.6),
              ),
            ),

            SizedBox(height: isTablet ? 32 : 24),

            Text(
              'لا توجد إشعارات',
              style: TextStyle(
                fontSize: isTablet ? 26 : 22,
                fontWeight: FontWeight.w800,
                color: Colors.grey[700],
                letterSpacing: -0.5,
              ),
            ),

            SizedBox(height: isTablet ? 12 : 8),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 60 : 40),
              child: Text(
                'سيظهر هنا جميع الإشعارات الخاصة بالطلبات والعروض والتذكيرات المهمة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
            ),

            SizedBox(height: isTablet ? 32 : 24),

            // 🔹 Action Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor,
                    const Color(0xFF6FB9E3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _notifications.addAll([
                        NotificationItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: 'مرحباً بعودتك! 👋',
                          message: 'نتمنى لك يوماً صحياً ومليئاً بالطاقة الإيجابية',
                          time: DateTime.now(),
                          type: NotificationType.system,
                          isRead: false,
                          icon: Icons.health_and_safety_rounded,
                          iconColor: _primaryColor,
                          gradient: [_primaryColor, const Color(0xFF6FB9E3)],
                        ),
                      ]);
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 40 : 32,
                      vertical: isTablet ? 16 : 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white,
                            size: isTablet ? 22 : 18),
                        SizedBox(width: isTablet ? 12 : 8),
                        Text(
                          'تحديث الإشعارات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onDismissed;
  final VoidCallback onTap;
  final Color primaryColor;
  final bool isTablet;
  final bool isSmallScreen;

  const _NotificationCard({
    required this.notification,
    required this.onDismissed,
    required this.onTap,
    required this.primaryColor,
    required this.isTablet,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: _buildDismissibleBackground(),
      onDismissed: (direction) => onDismissed(),
      child: ScaleTransition(
        scale: AlwaysStoppedAnimation(1.0),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: isTablet ? 4 : 2),
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: notification.isRead
                        ? Colors.grey[100]!
                        : primaryColor.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Gradient Icon Container
                    Container(
                      width: isTablet ? 50 : 44,
                      height: isTablet ? 50 : 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: notification.gradient,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: notification.gradient[0].withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        notification.icon,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),

                    SizedBox(width: isTablet ? 16 : 12),

                    // 🔹 Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey[900],
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // 🔹 Time and Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatTime(notification.time),
                                    style: TextStyle(
                                      fontSize: isTablet ? 12 : 10,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  if (!notification.isRead)
                                    Container(
                                      width: isTablet ? 10 : 8,
                                      height: isTablet ? 10 : 8,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: isTablet ? 8 : 6),

                          Text(
                            notification.message,
                            style: TextStyle(
                              fontSize: isTablet ? 15 : 13,
                              color: Colors.grey[700],
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: isTablet ? 8 : 6),

                          // 🔹 Notification Type Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 12 : 8,
                              vertical: isTablet ? 4 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(notification.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getTypeText(notification.type),
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                color: _getTypeColor(notification.type),
                                fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }

  Widget _buildDismissibleBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
          SizedBox(width: 8),
          Text(
            'حذف',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inHours < 1) return '${difference.inMinutes} د';
    if (difference.inDays < 1) return '${difference.inHours} س';
    if (difference.inDays < 7) return '${difference.inDays} ي';
    return DateFormat('MM/dd').format(time);
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.order: return Colors.green;
      case NotificationType.promotion: return Colors.orange;
      case NotificationType.reminder: return Colors.blue;
      case NotificationType.prescription: return Colors.purple;
      case NotificationType.nearby: return Colors.red;
      case NotificationType.system: return const Color(0xFF5EABD6);
    }
  }

  String _getTypeText(NotificationType type) {
    switch (type) {
      case NotificationType.order: return 'طلب';
      case NotificationType.promotion: return 'عرض';
      case NotificationType.reminder: return 'تذكير';
      case NotificationType.prescription: return 'وصفة';
      case NotificationType.nearby: return 'قريب';
      case NotificationType.system: return 'نظام';
    }
  }
}

enum NotificationType {
  order,
  promotion,
  reminder,
  prescription,
  nearby,
  system,
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  bool isRead;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    required this.isRead,
    required this.icon,
    required this.iconColor,
    required this.gradient,
  });
}