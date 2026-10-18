import 'package:flutter/material.dart';

/// Kept outside the medicines/count/search payload until explicitly entered.
class UncertainPrescriptionTextCard extends StatelessWidget {
  const UncertainPrescriptionTextCard({
    super.key,
    required this.texts,
    required this.onReview,
  });
  final List<String> texts;
  final ValueChanged<String> onReview;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('نصوص لم تُصنّف كأدوية'),
      subtitle: const Text(
        'راجعها إذا كان دواء ناقصًا. لا تدخل في البحث تلقائيًا.',
      ),
      children: [
        for (final text in texts)
          ListTile(
            title: Text(text, textDirection: TextDirection.ltr),
            trailing: TextButton(
              onPressed: () => onReview(text),
              child: const Text('مراجعة الاسم'),
            ),
          ),
      ],
    ),
  );
}
