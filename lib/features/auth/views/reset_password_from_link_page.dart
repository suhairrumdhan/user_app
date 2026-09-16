import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/app/core/widgets/custom_text_field.dart';
import 'package:user_application/features/auth/services/email_action_service.dart';
import 'package:user_application/features/auth/views/email_verification_page.dart';
import 'package:user_application/features/auth/views/login_page.dart';
import 'package:user_application/features/health_records/views/health_info.dart';
import 'package:user_application/features/pharmacy/views/home_page.dart';

class ResetPasswordFromLinkPage extends StatefulWidget {
  const ResetPasswordFromLinkPage({super.key, required this.actionCode});

  final String actionCode;

  @override
  State<ResetPasswordFromLinkPage> createState() =>
      _ResetPasswordFromLinkPageState();
}

class _ResetPasswordFromLinkPageState extends State<ResetPasswordFromLinkPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCheckingCode = true;
  bool _isSaving = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _email;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _validateActionCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateActionCode() async {
    try {
      final email = await _auth.verifyPasswordResetCode(widget.actionCode);
      if (!mounted) return;
      setState(() {
        _email = email;
        _isCheckingCode = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _codeError = _actionCodeErrorMessage(error);
        _isCheckingCode = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _codeError = 'تعذر التحقق من الرابط. اطلب رابطاً جديداً.';
        _isCheckingCode = false;
      });
    }
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'يرجى إدخال كلمة المرور الجديدة';
    if (password.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'يجب أن تحتوي على حرف إنجليزي كبير';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'يجب أن تحتوي على حرف إنجليزي صغير';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'يجب أن تحتوي على رقم';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'يجب أن تحتوي على رمز خاص';
    }
    return null;
  }

  Future<void> _savePasswordAndSignIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _email == null) return;

    setState(() => _isSaving = true);
    var passwordWasChanged = false;
    try {
      final newPassword = _passwordController.text;
      await _auth.confirmPasswordReset(
        code: widget.actionCode,
        newPassword: newPassword,
      );
      passwordWasChanged = true;

      await _auth.signOut();
      final credential = await _auth.signInWithEmailAndPassword(
        email: _email!,
        password: newPassword,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('تعذر إنشاء جلسة تسجيل الدخول');
      }

      if (EmailActionService.requiresEmailVerification(user)) {
        Get.offAll(() => const EmailVerificationPage());
      } else {
        await _openAuthenticatedDestination(user);
      }

      _showMessage('تم تغيير كلمة المرور وتسجيل الدخول بنجاح.', isError: false);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (passwordWasChanged) {
        Get.offAll(() => const LoginPage());
        _showMessage(
          'تم تغيير كلمة المرور، لكن تعذر تسجيل الدخول تلقائياً. استخدم كلمة المرور الجديدة.',
          isError: true,
        );
      } else {
        _showMessage(_resetErrorMessage(error), isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      if (passwordWasChanged) {
        Get.offAll(() => const LoginPage());
        _showMessage(
          'تم تغيير كلمة المرور. سجّل الدخول باستخدام كلمة المرور الجديدة.',
          isError: true,
        );
      } else {
        _showMessage('تعذر تغيير كلمة المرور. حاول مرة أخرى.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        return 'انتهت صلاحية الرابط. اطلب رابط استعادة جديداً.';
      case 'invalid-action-code':
        return 'الرابط غير صالح أو تم استخدامه مسبقاً.';
      case 'user-disabled':
        return 'هذا الحساب معطل. يرجى التواصل مع الدعم.';
      default:
        return 'تعذر التحقق من الرابط. اطلب رابطاً جديداً.';
    }
  }

  String _resetErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'expired-action-code':
        return 'انتهت صلاحية الرابط. اطلب رابط استعادة جديداً.';
      case 'invalid-action-code':
        return 'الرابط غير صالح أو تم استخدامه مسبقاً.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مجدداً.';
      default:
        return 'تعذر تغيير كلمة المرور حالياً. حاول مرة أخرى.';
    }
  }

  void _showMessage(String message, {required bool isError}) {
    Get.snackbar(
      isError ? 'تنبيه' : 'تم بنجاح',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
      colorText: isError ? Colors.red.shade900 : Colors.green.shade900,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      child: CustomScaffold(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: BoxConstraints(minHeight: height * 0.7),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: SingleChildScrollView(child: _buildContent()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isCheckingCode) {
      return const SizedBox(
        height: 360,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF5EABD6)),
        ),
      );
    }

    if (_codeError != null) {
      return Column(
        children: [
          const Icon(Icons.link_off_rounded, size: 72, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'رابط غير صالح',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _codeError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Color(0xFF607080),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Get.offAll(() => const LoginPage()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EABD6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('العودة إلى تسجيل الدخول'),
            ),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 46,
              color: Color(0xFF5EABD6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'إنشاء كلمة مرور جديدة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'أدخل كلمة المرور الجديدة مرة واحدة هنا، وبعد نجاح التغيير سيسجّل التطبيق دخولك تلقائياً.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Color(0xFF607080),
            ),
          ),
          if (_email != null) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                _email!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          CustomTextField(
            controller: _passwordController,
            label: 'كلمة المرور الجديدة',
            isPasswordField: true,
            showPassword: _showPassword,
            onVisibilityToggle: () {
              setState(() => _showPassword = !_showPassword);
            },
            validator: _validatePassword,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'تأكيد كلمة المرور الجديدة',
            isPasswordField: true,
            showPassword: _showConfirmPassword,
            onVisibilityToggle: () {
              setState(() => _showConfirmPassword = !_showConfirmPassword);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى تأكيد كلمة المرور الجديدة';
              }
              if (value != _passwordController.text) {
                return 'كلمتا المرور غير متطابقتين';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePasswordAndSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EABD6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ وتسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
