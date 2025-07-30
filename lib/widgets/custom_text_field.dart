import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType inputType;
  final String? Function(String?)? validator;
  final String? hintText;
  final bool isPasswordField;
  final VoidCallback? onVisibilityToggle;
  final bool? showPassword;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.inputType = TextInputType.text,
    this.validator,
    this.hintText,
    this.isPasswordField = false,
    this.onVisibilityToggle,
    this.showPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: inputType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: obscure
              ? const Icon(Icons.lock_outline)
              : inputType == TextInputType.phone
              ? const Icon(Icons.phone)
              : const Icon(Icons.person),
          suffixIcon: isPasswordField
              ? IconButton(
            icon: Icon(
              showPassword! ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: onVisibilityToggle,
          )
              : null,
        ),
      ),
    );
  }
}
