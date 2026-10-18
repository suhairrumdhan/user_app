import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/features/auth/views/login_page.dart';
import 'package:user_application/features/auth/views/reset_password_from_link_page.dart';
import 'package:user_application/features/health_records/views/health_info.dart';
import 'package:user_application/features/pharmacy/views/home_page.dart';

class EmailActionLinkController extends GetxController {
  final AppLinks _appLinks = AppLinks();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _handledActions = <String>{};
  StreamSubscription<Uri>? _linkSubscription;

  static const Set<String> _trustedHosts = <String>{
    'pharma-apps.firebaseapp.com',
    'pharma-apps.web.app',
  };

  @override
  void onInit() {
    super.onInit();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _scheduleLinkHandling,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('تعذر استقبال رابط المصادقة: $error');
      },
    );
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }

  void _scheduleLinkHandling(Uri incomingUri) {
    final actionUri = _extractActionUri(incomingUri);
    if (actionUri == null) return;

    final mode = actionUri.queryParameters['mode'];
    final actionCode = actionUri.queryParameters['oobCode'];
    if (mode == null || actionCode == null || actionCode.isEmpty) return;

    final actionKey = '$mode:$actionCode';
    if (!_handledActions.add(actionKey)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleEmailAction(mode: mode, actionCode: actionCode));
    });
  }

  Uri? _extractActionUri(Uri incomingUri) {
    if (_isTrustedActionUri(incomingUri)) return incomingUri;

    for (final parameterName in const <String>['link', 'deep_link_id']) {
      final nestedValue = incomingUri.queryParameters[parameterName];
      if (nestedValue == null || nestedValue.isEmpty) continue;

      final nestedUri = Uri.tryParse(nestedValue);
      if (nestedUri != null && _isTrustedActionUri(nestedUri)) {
        return nestedUri;
      }
    }

    return null;
  }

  bool _isTrustedActionUri(Uri uri) {
    if (uri.scheme != 'https' || !_trustedHosts.contains(uri.host)) {
      return false;
    }

    final hasSupportedPath =
        uri.path.startsWith('/__/auth/action') ||
        uri.path.startsWith('/__/auth/links');
    return hasSupportedPath &&
        uri.queryParameters['mode'] != null &&
        uri.queryParameters['oobCode'] != null;
  }

  Future<void> _handleEmailAction({
    required String mode,
    required String actionCode,
  }) async {
    switch (mode) {
      case 'resetPassword':
        Get.offAll(() => ResetPasswordFromLinkPage(actionCode: actionCode));
        return;
      case 'verifyEmail':
        await _verifyEmail(actionCode);
        return;
      default:
        return;
    }
  }

  Future<void> _verifyEmail(String actionCode) async {
    try {
      await _auth.applyActionCode(actionCode);
      final user = _auth.currentUser;

      if (user == null) {
        Get.offAll(() => const LoginPage());
        _showMessage(
          title: 'تم تأكيد البريد',
          message: 'تم تأكيد البريد. سجل الدخول الآن.',
        );
        return;
      }

      await user.reload();
      await _auth.currentUser?.getIdToken(true);
      await _openAuthenticatedDestination(_auth.currentUser ?? user);
      _showMessage(title: 'تم التأكيد', message: 'تم تأكيد البريد الإلكتروني.');
    } on FirebaseAuthException catch (error) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        if (_auth.currentUser?.emailVerified == true) {
          await _openAuthenticatedDestination(_auth.currentUser!);
          return;
        }
      }

      _showMessage(
        title: 'تعذر تأكيد البريد',
        message: _actionCodeErrorMessage(error),
        isError: true,
      );
    } catch (_) {
      _showMessage(
        title: 'تعذر تأكيد البريد',
        message: 'تعذر فتح الرابط. استخدم أحدث رسالة بريد.',
        isError: true,
      );
    }
  }

  Future<void> _openAuthenticatedDestination(User user) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final healthInfoCompleted = userDoc.data()?['healthInfoCompleted'] == true;

    if (healthInfoCompleted) {
      Get.offAll(() => const HomePage());
    } else {
      Get.offAll(() => const HealthInfoScreen());
    }
  }

  String _actionCodeErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'expired-action-code':
        return 'انتهت صلاحية الرابط. اطلب رابطاً جديداً من التطبيق.';
      case 'invalid-action-code':
        return 'الرابط غير صالح أو تم استخدامه مسبقاً. اطلب رابطاً جديداً.';
      case 'user-disabled':
        return 'الحساب معطل. تواصل مع الدعم.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مجدداً.';
      default:
        return 'تعذر تنفيذ الرابط. اطلب رابطاً جديداً وحاول مرة أخرى.';
    }
  }

  void _showMessage({
    required String title,
    required String message,
    bool isError = false,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
      colorText: isError ? Colors.red.shade900 : Colors.green.shade900,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}
