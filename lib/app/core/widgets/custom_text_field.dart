import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

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

  final void Function(String)? onChanged;
  final VoidCallback? onTap; // ✅ أضفنا onTap
  final IconData? icon;

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
    this.onChanged,
    this.onTap, // ✅ هنا
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const Color pPrimaryColor = Color(0xFF5EABD6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPasswordField ? !(showPassword ?? false) : obscure,
        keyboardType: inputType,
        validator: validator,
        onChanged: onChanged,
        readOnly: onTap != null, // ✅ إذا فيه onTap نخليه readonly
        onTap: onTap,           // ✅ هنا
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF2C3E50),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: const TextStyle(
            color: Color(0xFF7F8C8D),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon ??
                (isPasswordField
                    ? Iconsax.lock
                    : inputType == TextInputType.phone
                    ? Iconsax.call
                    : inputType == TextInputType.emailAddress
                    ? Iconsax.sms
                    : Iconsax.user),
            color: pPrimaryColor,
            size: 20,
          ),
          suffixIcon: isPasswordField
              ? IconButton(
            icon: Icon(
              (showPassword ?? false) ? Iconsax.eye_slash : Iconsax.eye,
              color: pPrimaryColor,
              size: 20,
            ),
            onPressed: onVisibilityToggle,
          )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: pPrimaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}