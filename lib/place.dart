/// A searchable location (a city, town, region...).
class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
    this.countryCode,
  });

  final String name;
  final double latitude;
  final double longitude;

  /// State or province, when known.
  final String? region;
  final String? country;

  /// ISO 3166-1 alpha-2 code, e.g. "IN". Used later for the country outline.
  final String? countryCode;

  /// Stable key used to tell places apart (two decimals is ~1 km).
  String get id =>
      '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';

  /// "Bengaluru, India"
  String get label =>
      (country == null || country!.isEmpty) ? name : '$name, $country';

  /// "Karnataka, India" (empty when nothing else is known).
  String get subtitle => [region, country]
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .join(', ');

  factory Place.fromGeocoding(Map<String, dynamic> json) {
    return Place(
      name: json['name'] as String? ?? 'Unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      region: json['admin1'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
    );
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      region: json['region'] as String?,
      country: json['country'] as String?,
      countryCode: json['cc'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': latitude,
        'lon': longitude,
        'region': region,
        'country': country,
        'cc': countryCode,
      };
}
