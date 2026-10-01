import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/maps/map_config.dart';
import '../../core/network/connection_controller.dart';
import '../offline_vault/live_emergency_repository.dart';
import 'offline_map_service.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key, required this.connectionController});

  final ConnectionController connectionController;

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final OfflineMapService _mapService = const OfflineMapService();

  final LiveEmergencyRepository _repository = LiveEmergencyRepository();

  MapLibreMapController? _mapController;

  LiveEmergencySnapshot? _snapshot;

  List<Circle> _markers = [];

  bool _loading = true;
  bool _mapReady = false;
  bool _downloading = false;

  double _downloadProgress = 0;

  String? _error;

  int? _offlineRegionId;

  StreamSubscription<dynamic>? _dummySubscription;

  @override
  void initState() {
    super.initState();

    widget.connectionController.addListener(_connectionChanged);

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final snapshot = await _repository.getBestAvailable();

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });

      await _loadExistingOfflineRegion();

      if (_mapReady) {
        await _configureMapMode();
        await _addNearbyMarkers();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _connectionChanged() {
    _configureMapMode();
  }

  Future<void> _configureMapMode() async {
    try {
      await setOffline(!widget.connectionController.isOnline);
    } catch (_) {
      // MapLibre may reject this before native map initialization completes.
    }
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _mapController = controller;

    await _configureMapMode();
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _mapReady = true;
    });

    await _configureMapMode();
    await _addNearbyMarkers();
  }

  Future<void> _addNearbyMarkers() async {
    final controller = _mapController;

    final snapshot = _snapshot;

    if (controller == null || snapshot == null || !_mapReady) {
      return;
    }

    try {
      for (final marker in _markers) {
        try {
          await controller.removeCircle(marker);
        } catch (_) {}
      }

      _markers.clear();

      final places = snapshot.nearbyPlaces;

      for (final place in places) {
        final circle = await controller.addCircle(
          CircleOptions(
            geometry: LatLng(place.latitude, place.longitude),
            circleRadius: 9,
            circleColor: _markerColor(place.category),
            circleOpacity: 0.95,
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
            circleStrokeOpacity: 0.9,
          ),
          {
            'name': place.name,
            'category': place.category,
            'distance': place.distanceLabel,
            'phone': place.phone,
            'address': place.address,
          },
        );

        _markers.add(circle);
      }
    } catch (error) {
      debugPrint('Map marker error: $error');
    }
  }

  String _markerColor(String category) {
    switch (category) {
      case 'Hospital':
        return '#FF3B3B';

      case 'Clinic':
        return '#FF6B6B';

      case 'Pharmacy':
        return '#F4B73C';

      case 'Police':
        return '#C0C0C0';

      case 'Fire Station':
        return '#FF3B3B';

      case 'Ambulance':
        return '#CD7F32';

      case 'Shelter':
        return '#8A8A8A';

      default:
        return '#FFFFFF';
    }
  }

  Future<void> _loadExistingOfflineRegion() async {
    if (!MapConfig.isConfigured) {
      return;
    }

    try {
      final regions = await getListOfRegions();

      if (regions.isEmpty) {
        return;
      }

      /*
       * Use the newest region created by OfflineLink.
       */
      regions.sort((a, b) => b.id.compareTo(a.id));

      final region = regions.first;

      final metadata = region.metadata;

      if (metadata['app'] == 'OfflineLink') {
        _offlineRegionId = region.id;
      }
    } catch (_) {
      // Nothing downloaded yet.
    }
  }

  Future<void> _downloadMyArea() async {
    if (_downloading) {
      return;
    }

    if (!MapConfig.isConfigured) {
      _showMessage('Add your Stadia Maps API key first.');
      return;
    }

    if (!widget.connectionController.isOnline) {
      _showMessage('Connect to the Internet before downloading the map.');
      return;
    }

    final snapshot = _snapshot;

    if (snapshot == null) {
      _showMessage('Your location is not available yet.');
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _error = null;
    });

    try {
      /*
       * Remove the previous OfflineLink area.
       *
       * This keeps us from continuously accumulating
       * multiple overlapping packs.
       */
      if (_offlineRegionId != null) {
        try {
          await deleteOfflineRegion(_offlineRegionId!);
        } catch (_) {}

        _offlineRegionId = null;
      }

      final definition = _mapService.buildRegionDefinition(snapshot.location);

      final region = await downloadOfflineRegion(
        definition,
        metadata: {
          'app': 'OfflineLink',
          'type': 'emergency_area',
          'latitude': snapshot.location.latitude,
          'longitude': snapshot.location.longitude,
          'radiusKm': MapConfig.offlineRadiusKm,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        onEvent: (status) {
          if (!mounted) {
            return;
          }

          if (status is InProgress) {
            setState(() {
              _downloadProgress = status.progress.clamp(0.0, 1.0);
            });
          }

          if (status is Success) {
            setState(() {
              _downloadProgress = 1.0;
            });
          }

          if (status is Error) {
            setState(() {
              _error = 'Map download failed.';
            });
          }
        },
      );

      _offlineRegionId = region.id;

      if (!mounted) {
        return;
      }

      setState(() {
        _downloadProgress = 1.0;
      });

      _showMessage('Your emergency map is now stored offline.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });

      _showMessage('Map download failed. Try again with a stable connection.');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<void> _deleteOfflineMap() async {
    final id = _offlineRegionId;

    if (id == null) {
      return;
    }

    try {
      await deleteOfflineRegion(id);

      _offlineRegionId = null;

      /*
       * Clear tiles that are no longer pinned to
       * an offline region.
       */
      await clearAmbientCache();

      if (!mounted) {
        return;
      }

      setState(() {});

      _showMessage('Offline map removed from this device.');
    } catch (error) {
      _showMessage('Could not remove the offline map.');
    }
  }

  Future<void> _centerOnMe() async {
    final controller = _mapController;

    final snapshot = _snapshot;

    if (controller == null || snapshot == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(snapshot.location.latitude, snapshot.location.longitude),
        14,
      ),
    );
  }

  Future<void> _openPlace(NearbyPlace place) async {
    if (place.phone != null && place.phone!.isNotEmpty) {
      final uri = Uri(scheme: 'tel', path: place.phone);

      try {
        await launchUrl(uri);
        return;
      } catch (_) {}
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${place.latitude},${place.longitude}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _downloadStatusText() {
    if (_downloading) {
      return 'Downloading ${(100 * _downloadProgress).round()}%';
    }

    if (_offlineRegionId != null) {
      return 'Offline map ready';
    }

    return 'No offline map saved';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Emergency Map',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_offlineRegionId != null)
            IconButton(
              onPressed: _deleteOfflineMap,
              tooltip: 'Remove offline map',
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!MapConfig.isConfigured) {
      return _configurationRequired();
    }

    if (_loading || _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MapLibreMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _snapshot!.location.latitude,
              _snapshot!.location.longitude,
            ),
            zoom: 14,
          ),
          styleString: MapConfig.styleUrl,
          myLocationEnabled: true,
          myLocationTrackingMode: MyLocationTrackingMode.none,
          compassEnabled: true,
          logoEnabled: true,
          logoViewPosition: LogoViewPosition.bottomLeft,
          logoViewMargins: const Point(10, 80),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick: _handleMapTap,
        ),
        _topStatus(),
        _bottomPanel(),
        _centerButton(),
        _attribution(),
      ],
    );
  }

  Widget _configurationRequired() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                color: Color(0xFFFF3B3B),
                size: 56,
              ),
              const SizedBox(height: 18),
              const Text(
                'Map provider setup required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Add your real Stadia Maps API key using STADIA_MAPS_API_KEY, then restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topStatus() {
    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xEE141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _offlineRegionId != null
                  ? const Color(0xFF2E8B57)
                  : const Color(0xFF333333),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _offlineRegionId != null
                    ? Icons.offline_pin_rounded
                    : Icons.map_rounded,
                size: 20,
                color: _offlineRegionId != null
                    ? Colors.greenAccent
                    : const Color(0xFFF4B73C),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _downloadStatusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    final count = _snapshot!.nearbyPlaces.length;

    return Positioned(
      left: 14,
      right: 14,
      bottom: 18,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xF5151515),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF303030)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFFF5555),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _snapshot!.location.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '$count nearby emergency places',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
              ),
              const SizedBox(height: 12),
              if (_downloading)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 7,
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.connectionController.isOnline
                        ? _downloadMyArea
                        : null,
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(
                      _offlineRegionId != null
                          ? 'Update Offline Area'
                          : 'Download My Area',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return Positioned(
      right: 15,
      bottom: 184,
      child: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'center_on_me',
          onPressed: _centerOnMe,
          backgroundColor: const Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          child: const Icon(Icons.my_location_rounded),
        ),
      ),
    );
  }

  Widget _attribution() {
    return const Positioned(
      left: 10,
      bottom: 94,
      child: SafeArea(
        child: IgnorePointer(
          child: Text(
            MapConfig.attribution,
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 9,
              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMapTap(Point<num> point, LatLng coordinates) {
    /*
     * MapLibre circle annotations are deliberately
     * lightweight. If the user taps the map, we use
     * a tiny nearest-place calculation to open the
     * matching emergency place.
     */
    _showNearestPlace(coordinates);
  }

  void _showNearestPlace(LatLng coordinates) {
    final places = _snapshot!.nearbyPlaces;

    if (places.isEmpty) {
      return;
    }

    NearbyPlace? nearest;

    double nearestDistance = double.infinity;

    for (final place in places) {
      final distance = _approximateDistanceMeters(
        coordinates.latitude,
        coordinates.longitude,
        place.latitude,
        place.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = place;
      }
    }

    if (nearest == null || nearestDistance > 500) {
      return;
    }

    final place = nearest;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${place.category} • '
                '${place.distanceLabel}',
                style: const TextStyle(
                  color: Color(0xFFF4B73C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (place.address != null && place.address!.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  place.address!,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openPlace(place);
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Place'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _approximateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    const radians = 3.141592653589793 / 180.0;

    final dLat = (lat2 - lat1) * radians;

    final dLon = (lon2 - lon1) * radians;

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * radians) *
            cos(lat2 * radians) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  void dispose() {
    widget.connectionController.removeListener(_connectionChanged);

    _repository.dispose();

    _dummySubscription?.cancel();

    super.dispose();
  }
}
