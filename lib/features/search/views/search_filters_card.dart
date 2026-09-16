import 'package:flutter/material.dart';
import '../../search/models/pharmacy_search_filters.dart';
import 'search_ui_colors.dart';

class SearchFiltersCard extends StatelessWidget {
  final double selectedDistance;
  final bool useInsurance;
  final bool availableNowOnly;
  final bool fullMatchOnly;
  final bool similarProductsAllowed;
  final bool priceFilterEnabled;
  final String selectedSort;
  final double minimumAvailablePrice;
  final double maximumAvailablePrice;
  final RangeValues selectedPriceRange;
  final String priceRangeMode;

  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<bool> onInsuranceChanged;
  final ValueChanged<bool> onAvailableNowChanged;
  final ValueChanged<bool> onFullMatchChanged;
  final ValueChanged<bool> onSimilarProductsChanged;
  final ValueChanged<bool> onPriceFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<RangeValues> onPriceRangeChanged;
  final ValueChanged<String> onPriceRangeModeChanged;

  const SearchFiltersCard({
    super.key,
    required this.selectedDistance,
    required this.useInsurance,
    required this.availableNowOnly,
    required this.fullMatchOnly,
    required this.similarProductsAllowed,
    required this.priceFilterEnabled,
    required this.selectedSort,
    required this.minimumAvailablePrice,
    required this.maximumAvailablePrice,
    required this.selectedPriceRange,
    required this.priceRangeMode,
    required this.onDistanceChanged,
    required this.onInsuranceChanged,
    required this.onAvailableNowChanged,
    required this.onFullMatchChanged,
    required this.onSimilarProductsChanged,
    required this.onPriceFilterChanged,
    required this.onSortChanged,
    required this.onPriceRangeChanged,
    required this.onPriceRangeModeChanged,
  });

  static const List<_SortOption> _sortOptions = [
    _SortOption('الأقرب', PharmacySearchSort.nearest),
    _SortOption('الأقل سعرًا', PharmacySearchSort.cheapest),
    _SortOption('أفضل تطابق', PharmacySearchSort.bestMatch),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            max: 100,
            divisions: 99,
            activeColor: SearchUiColors.primary,
            inactiveColor: SearchUiColors.primary.withOpacity(0.18),
            label: selectedDistance.toStringAsFixed(0),
            onChanged: onDistanceChanged,
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: const [5.0, 10.0, 20.0, 50.0, 100.0].length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final value = const [5.0, 10.0, 20.0, 50.0, 100.0][index];
                final selected = selectedDistance == value;
                return ChoiceChip(
                  label: Text(value == 100 ? '100 كم' : '${value.toInt()} كم'),
                  selected: selected,
                  onSelected: (_) => onDistanceChanged(value),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          _filterToggle(
            title: 'إظهار منتجات مشابهة بالاسم',
            value: similarProductsAllowed,
            onChanged: onSimilarProductsChanged,
          ),
          const SizedBox(height: 8),
          _filterToggle(
            title: 'تحديد نطاق للسعر',
            value: priceFilterEnabled,
            onChanged: onPriceFilterChanged,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: priceFilterEnabled
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children:
                              const [
                                ('بين سعرين', 'between'),
                                ('ابتداءً من', 'minimumOnly'),
                                ('حتى سعر', 'maximumOnly'),
                              ].map((option) {
                                final selected = priceRangeMode == option.$2;
                                return ChoiceChip(
                                  label: Text(option.$1),
                                  selected: selected,
                                  onSelected: (_) =>
                                      onPriceRangeModeChanged(option.$2),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _priceRangeLabel(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: SearchUiColors.darkText,
                          ),
                        ),
                        if (priceRangeMode == 'between')
                          RangeSlider(
                            values: selectedPriceRange,
                            min: minimumAvailablePrice,
                            max: maximumAvailablePrice,
                            divisions: _priceDivisions,
                            labels: RangeLabels(
                              '${selectedPriceRange.start.round()} د.ل',
                              '${selectedPriceRange.end.round()} د.ل',
                            ),
                            activeColor: SearchUiColors.primary,
                            inactiveColor: SearchUiColors.primary.withOpacity(
                              0.18,
                            ),
                            onChanged: onPriceRangeChanged,
                          )
                        else
                          Slider(
                            value: priceRangeMode == 'minimumOnly'
                                ? selectedPriceRange.start
                                : selectedPriceRange.end,
                            min: minimumAvailablePrice,
                            max: maximumAvailablePrice,
                            divisions: _priceDivisions,
                            label: priceRangeMode == 'minimumOnly'
                                ? '${selectedPriceRange.start.round()} د.ل'
                                : '${selectedPriceRange.end.round()} د.ل',
                            activeColor: SearchUiColors.primary,
                            inactiveColor: SearchUiColors.primary.withOpacity(
                              0.18,
                            ),
                            onChanged: (value) {
                              onPriceRangeChanged(
                                priceRangeMode == 'minimumOnly'
                                    ? RangeValues(value, selectedPriceRange.end)
                                    : RangeValues(
                                        selectedPriceRange.start,
                                        value,
                                      ),
                              );
                            },
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${minimumAvailablePrice.round()} د.ل',
                              style: const TextStyle(
                                color: SearchUiColors.softText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${maximumAvailablePrice.round()} د.ل',
                              style: const TextStyle(
                                color: SearchUiColors.softText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
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
            children: _sortOptions.map((option) {
              final selected = selectedSort == option.value;
              return GestureDetector(
                onTap: () => onSortChanged(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
        dense: true,
        visualDensity: VisualDensity.compact,
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

  int get _priceDivisions {
    final difference = (maximumAvailablePrice - minimumAvailablePrice).round();
    return difference.clamp(1, 100).toInt();
  }

  String _priceRangeLabel() {
    final minimum = selectedPriceRange.start.round();
    final maximum = selectedPriceRange.end.round();
    switch (priceRangeMode) {
      case 'minimumOnly':
        return 'السعر: $minimum د.ل أو أكثر';
      case 'maximumOnly':
        return 'السعر: حتى $maximum د.ل';
      default:
        return 'السعر: من $minimum إلى $maximum د.ل';
    }
  }
}

class _SortOption {
  final String label;
  final String value;

  const _SortOption(this.label, this.value);
}
