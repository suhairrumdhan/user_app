class PharmacySearchFilters {
  final double maxDistanceKm;
  final bool insuranceOnly;
  final bool availableNowOnly;
  final bool fullMatchOnly;
  final bool alternativesAllowed;
  final String sortBy;
  final double? minPrice;
  final double? maxPrice;

  const PharmacySearchFilters({
    this.maxDistanceKm = 5,
    this.insuranceOnly = false,
    this.availableNowOnly = false,
    this.fullMatchOnly = false,
    this.alternativesAllowed = true,
    this.sortBy = PharmacySearchSort.nearest,
    this.minPrice,
    this.maxPrice,
  });

  PharmacySearchFilters copyWith({
    double? maxDistanceKm,
    bool? insuranceOnly,
    bool? availableNowOnly,
    bool? fullMatchOnly,
    bool? alternativesAllowed,
    String? sortBy,
    double? minPrice,
    double? maxPrice,
  }) {
    return PharmacySearchFilters(
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      insuranceOnly: insuranceOnly ?? this.insuranceOnly,
      availableNowOnly: availableNowOnly ?? this.availableNowOnly,
      fullMatchOnly: fullMatchOnly ?? this.fullMatchOnly,
      alternativesAllowed: alternativesAllowed ?? this.alternativesAllowed,
      sortBy: sortBy ?? this.sortBy,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }
}

class PharmacySearchSort {
  static const String nearest = 'nearest';
  static const String cheapest = 'cheapest';
  static const String bestRated = 'bestRated';
  static const String bestMatch = 'bestMatch';
}