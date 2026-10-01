import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/maps/map_config.dart';
import '../offline_vault/live_emergency_repository.dart';

class OfflineMapService {
  const OfflineMapService();

  LatLngBounds buildOfflineBounds(
      DeviceLocation location,
      ) {
    final latitude =
        location.latitude;

    final longitude =
        location.longitude;

    final radiusKm =
        MapConfig.offlineRadiusKm;

    /*
     * Approximate degrees-per-kilometer.
     *
     * Longitude degree length changes with latitude,
     * so we compensate using cosine(latitude).
     */
    final latitudeDelta =
        radiusKm / 111.32;

    final longitudeDelta =
        radiusKm /
            (111.32 *
                math.cos(
                  latitude *
                      math.pi /
                      180,
                ).abs());

    return LatLngBounds(
      southwest: LatLng(
        latitude - latitudeDelta,
        longitude - longitudeDelta,
      ),
      northeast: LatLng(
        latitude + latitudeDelta,
        longitude + longitudeDelta,
      ),
    );
  }

  OfflineRegionDefinition
  buildRegionDefinition(
      DeviceLocation location,
      ) {
    return OfflineRegionDefinition(
      bounds: buildOfflineBounds(
        location,
      ),
      mapStyleUrl:
      MapConfig.styleUrl,
      minZoom:
      MapConfig.offlineMinZoom,
      maxZoom:
      MapConfig.offlineMaxZoom,
    );
  }
}