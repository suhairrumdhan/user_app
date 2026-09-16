import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/features/auth/services/email_action_service.dart';
import 'package:user_application/features/auth/views/login_page.dart';
import 'package:user_application/features/health_records/views/health_info.dart';
import 'package:user_application/features/pharmacy/views/home_page.dart';

import '../../../app/core/services/push_notification_service.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, this.emailSent = false});

  final bool emailSent;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with WidgetsBindingObserver {
  final EmailActionService _emailActions = EmailActionService();
  Timer? _countdownTimer;
  int _resendSeconds = 0;
  bool _isChecking = false;
  bool _isResending = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.emailSent) {
      _startResendCountdown();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_checkVerification(showPendingMessage: false));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isChecking) {
      unawaited(_checkVerification(showPendingMessage: false));
    }
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _checkVerification({bool showPendingMessage = true}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final isVerified = await _emailActions.reloadAndCheckEmailVerified();
      if (!mounted) return;

      if (!isVerified) {
        if (showPendingMessage) {
          _showMessage(
            'لم يتم تأكيد البريد بعد. افتح الرابط الموجود في بريدك ثم حاول مرة أخرى.',
            isError: true,
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;

      final healthInfoCompleted =
          userDoc.data()?['healthInfoCompleted'] == true;
      if (healthInfoCompleted) {
        Get.offAll(() => const HomePage());
      } else {
        Get.offAll(() => const HealthInfoScreen());
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(_verificationErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'تعذر التحقق الآن. تأكد من اتصال الإنترنت وحاول مرة أخرى.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending || _resendSeconds > 0) return;
    setState(() => _isResending = true);

    try {
      await _emailActions.sendVerificationEmail();
      if (!mounted) return;
      _startResendCountdown();
      _showMessage('تم إرسال رابط تأكيد جديد إلى بريدك.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showMessage(_verificationErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'تعذر إرسال الرابط. تأكد من اتصال الإنترنت وحاول مرة أخرى.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await PushNotificationService.instance.unregisterCurrentDevice();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Get.offAll(() => const LoginPage());
  }

  String _verificationErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'تم إرسال طلبات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مجدداً.';
      case 'user-disabled':
        return 'هذا الحساب معطل. يرجى التواصل مع الدعم.';
      default:
        return 'تعذر تنفيذ الطلب حالياً. حاول مرة أخرى.';
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final email = _user?.email ?? '';

    return PopScope(
      canPop: false,
      child: CustomScaffold(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(minHeight: height * 0.68),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F4FA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 44,
                      color: Color(0xFF5EABD6),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'تأكيد البريد الإلكتروني',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'أرسلنا رابط التأكيد إلى بريدك الإلكتروني. افتح الرسالة واضغط على الرابط؛ سيفتح التطبيق ويكمل الدخول تلقائياً. إذا لم ينتقل وحده، استخدم زر المتابعة أدناه.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Color(0xFF607080),
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : _checkVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5EABD6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isChecking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'تم التأكيد، متابعة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isResending || _resendSeconds > 0
                        ? null
                        : _resendVerificationEmail,
                    child: _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _resendSeconds > 0
                                ? 'إعادة الإرسال بعد $_resendSeconds ثانية'
                                : 'إعادة إرسال رابط التأكيد',
                          ),
                  ),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text(
                      'استخدام حساب آخر',
                      style: TextStyle(color: Color(0xFF607080)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
