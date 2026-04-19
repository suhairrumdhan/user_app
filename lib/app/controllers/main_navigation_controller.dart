import 'package:get/get.dart';

class MainNavigationController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxnString pendingOrderId = RxnString();

  void changeIndex(int index) {
    currentIndex.value = index;
  }

  void goHome() => changeIndex(0);
  void goChats() => changeIndex(1);

  void goOrders({String? orderId}) {
    if (orderId != null && orderId.trim().isNotEmpty) {
      pendingOrderId.value = orderId;
    }
    changeIndex(2);
  }

  void goNotifications() => changeIndex(3);
  void goProfile() => changeIndex(4);

  void clearPendingOrderId() {
    pendingOrderId.value = null;
  }
}