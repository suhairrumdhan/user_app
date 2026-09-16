import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_application/app/core/widgets/custom_scaffold.dart';
import 'package:user_application/app/core/widgets/custom_text_field.dart';
import 'package:user_application/features/auth/services/email_action_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.initialEmail = '',
    this.fromProfile = false,
  });

  final String initialEmail;
  final bool fromProfile;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final EmailActionService _emailActions = EmailActionService();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (widget.fromProfile) {
      if (!EmailActionService.usesEmailPassword(currentUser) ||
          currentUser?.email == null) {
        _showError('إعادة التعيين متاحة فقط لحسابات البريد وكلمة المرور.');
        return;
      }
    } else if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _emailActions.sendPasswordResetEmail(
        widget.fromProfile ? currentUser!.email! : _emailController.text,
      );
      if (!mounted) return;
      setState(() => _emailSent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showError(_resetErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showError('تعذر إرسال الرابط. تحقق من اتصال الإنترنت وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resetErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'too-many-requests':
        return 'تم إرسال طلبات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مجدداً.';
      default:
        return 'تعذر إرسال رابط الاستعادة حالياً. حاول مرة أخرى.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return CustomScaffold(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(minHeight: height * 0.62),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: SingleChildScrollView(
            child: _emailSent ? _buildSuccessContent() : _buildFormContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F4FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 44,
              color: Color(0xFF5EABD6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.fromProfile
                ? 'إعادة تعيين كلمة المرور'
                : 'استعادة كلمة المرور',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.fromProfile
                ? 'سنرسل رابطاً آمناً إلى بريد حسابك لإنشاء كلمة مرور جديدة.'
                : 'أدخل بريدك الإلكتروني وسنرسل لك رابطاً آمناً لإنشاء كلمة مرور جديدة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Color(0xFF607080),
            ),
          ),
          const SizedBox(height: 26),
          if (widget.fromProfile)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                FirebaseAuth.instance.currentUser?.email ?? widget.initialEmail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            )
          else
            CustomTextField(
              controller: _emailController,
              label: 'البريد الإلكتروني',
              inputType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5EABD6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إرسال رابط الاستعادة',
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

  Widget _buildSuccessContent() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF7EF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 46,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'راجع بريدك الإلكتروني',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.fromProfile
              ? 'أرسلنا رابط تغيير كلمة المرور إلى بريد حسابك. تحقق أيضاً من مجلد الرسائل غير المرغوب فيها.'
              : 'إذا كان البريد مسجلاً لدينا فستصلك رسالة تحتوي على رابط تغيير كلمة المرور. تحقق أيضاً من مجلد الرسائل غير المرغوب فيها.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF607080)),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5EABD6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.fromProfile
                  ? 'العودة للملف الشخصي'
                  : 'العودة لتسجيل الدخول',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
