class MapConfig {
  const MapConfig._();

  static const String stadiaApiKey =
      'bbf90166-5fc9-494a-adde-bf3331b8968d';

  static bool get isConfigured =>
      stadiaApiKey.trim().isNotEmpty;

  static String get styleUrl {
    if (!isConfigured) {
      throw StateError(
        'Stadia Maps API key is missing.',
      );
    }

    return 'https://tiles.stadiamaps.com/'
        'styles/alidade_smooth_dark.json'
        '?api_key=$stadiaApiKey';
  }

  static const String attribution =
      '© Stadia Maps © OpenMapTiles © OpenStreetMap';

  static const double offlineRadiusKm = 2.0;

  static const double offlineMinZoom = 10.0;

  static const double offlineMaxZoom = 14.0;
}