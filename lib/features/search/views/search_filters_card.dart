import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../search/models/pharmacy_search_filters.dart';
import 'search_ui_colors.dart';

class SearchFiltersCard extends StatelessWidget {
  final double selectedDistance;
  final bool useInsurance;
  final bool availableNowOnly;
  final bool fullMatchOnly;
  final String selectedSort;

  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<bool> onInsuranceChanged;
  final ValueChanged<bool> onAvailableNowChanged;
  final ValueChanged<bool> onFullMatchChanged;
  final ValueChanged<String> onSortChanged;

  const SearchFiltersCard({
    super.key,
    required this.selectedDistance,
    required this.useInsurance,
    required this.availableNowOnly,
    required this.fullMatchOnly,
    required this.selectedSort,
    required this.onDistanceChanged,
    required this.onInsuranceChanged,
    required this.onAvailableNowChanged,
    required this.onFullMatchChanged,
    required this.onSortChanged,
  });

  static const List<_SortOption> sortOptions = [
    _SortOption('الأقرب', PharmacySearchSort.nearest),
    _SortOption('الأقل سعرًا', PharmacySearchSort.cheapest),
    _SortOption('أفضل تطابق', PharmacySearchSort.bestMatch),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Iconsax.setting_4, color: SearchUiColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'الفلاتر',
                style: TextStyle(
                  color: SearchUiColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'المسافة القصوى: ${selectedDistance.toStringAsFixed(0)} كم',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SearchUiColors.darkText,
            ),
          ),
          Slider(
            value: selectedDistance,
            min: 1,
            max: 20,
            divisions: 19,
            activeColor: SearchUiColors.primary,
            inactiveColor: SearchUiColors.primary.withOpacity(0.18),
            label: selectedDistance.toStringAsFixed(0),
            onChanged: onDistanceChanged,
          ),
          const SizedBox(height: 8),
          _filterToggle(
            title: 'إظهار الصيدليات التي تدعم التأمين فقط',
            value: useInsurance,
            onChanged: onInsuranceChanged,
          ),
          const SizedBox(height: 10),
          _filterToggle(
            title: 'إظهار الصيدليات المتاحة الآن فقط',
            value: availableNowOnly,
            onChanged: onAvailableNowChanged,
          ),
          const SizedBox(height: 10),
          _filterToggle(
            title: 'إظهار التطابق الكامل فقط',
            value: fullMatchOnly,
            onChanged: onFullMatchChanged,
          ),
          const SizedBox(height: 18),
          const Text(
            'ترتيب النتائج',
            style: TextStyle(
              color: SearchUiColors.darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sortOptions.map((option) {
              final selected = selectedSort == option.value;
              return GestureDetector(
                onTap: () => onSortChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? SearchUiColors.primary.withOpacity(0.12)
                        : SearchUiColors.light,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? SearchUiColors.primary
                          : SearchUiColors.primary.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: selected
                          ? SearchUiColors.primary
                          : SearchUiColors.darkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _filterToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: SearchUiColors.light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SearchUiColors.primary.withOpacity(0.10)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: SearchUiColors.accent,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SearchUiColors.darkText,
          ),
        ),
      ),
    );
  }
}

class _SortOption {
  final String label;
  final String value;

  const _SortOption(this.label, this.value);
}