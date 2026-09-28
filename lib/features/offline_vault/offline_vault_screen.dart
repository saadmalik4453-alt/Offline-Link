import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'live_emergency_repository.dart';

class OfflineVaultScreen extends StatefulWidget {
  const OfflineVaultScreen({super.key, required this.connectionController});

  final dynamic connectionController;

  @override
  State<OfflineVaultScreen> createState() => _OfflineVaultScreenState();
}

class _OfflineVaultScreenState extends State<OfflineVaultScreen> {
  final LiveEmergencyRepository _repository = LiveEmergencyRepository();

  LiveEmergencySnapshot? _snapshot;

  bool _loading = true;
  bool _refreshing = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      /*
       * Try live data first.
       *
       * If Internet is unavailable, repository
       * automatically falls back to the local cache.
       */
      final data = await _repository.getBestAvailable();

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = data;
        _loading = false;
      });
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

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      final data = await _repository.refresh();

      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = data;
      });

      _showMessage('Fresh location data downloaded and cached.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      /*
       * If refresh fails, try existing cache.
       */
      try {
        final cached = await _repository.loadOffline();

        if (!mounted) {
          return;
        }

        setState(() {
          _snapshot = cached;
          _error =
              'Live refresh failed. Showing '
              'your last saved data.';
        });
      } catch (_) {
        setState(() {
          _error = error.toString();
        });
      }

      _showMessage('Could not download fresh data.');
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);

    try {
      await launchUrl(uri);
    } catch (_) {
      _showMessage('Could not open the phone dialer.');
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);

    if (uri == null) {
      _showMessage('Invalid web address.');
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showMessage('Could not open the link.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year '
        '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Emergency Nearby',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            tooltip: 'Refresh using my location',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off_rounded,
                size: 50,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'No data available.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.location_searching_rounded),
                label: const Text('Get My Location'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 35),
        children: [
          _locationCard(snapshot),
          const SizedBox(height: 14),
          _dataStatusCard(snapshot),
          if (snapshot.weather != null) ...[
            const SizedBox(height: 22),
            _sectionTitle('Current Weather'),
            const SizedBox(height: 12),
            _weatherCard(snapshot.weather!),
          ],
          const SizedBox(height: 22),
          _sectionTitle('Emergency Contacts'),
          const SizedBox(height: 12),
          if (snapshot.contacts.isEmpty)
            _emptyCard(
              'No jurisdiction-specific official directory '
              'was available for this location yet.',
            )
          else
            ...snapshot.contacts.map(
              (contact) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _contactCard(contact),
              ),
            ),
          const SizedBox(height: 12),
          _sectionTitle('Nearby Services'),
          const SizedBox(height: 5),
          const Text(
            'Fresh places found within approximately 5 km of your location.',
            style: TextStyle(color: Color(0xFF777777), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (snapshot.nearbyPlaces.isEmpty)
            _emptyCard('No nearby mapped emergency facilities were found.')
          else
            ...snapshot.nearbyPlaces.map(
              (place) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _nearbyCard(place),
              ),
            ),
          const SizedBox(height: 22),
          _sectionTitle('Recent Earthquakes'),
          const SizedBox(height: 5),
          const Text(
            'USGS events from the last day within 1,000 km.',
            style: TextStyle(color: Color(0xFF777777), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (snapshot.earthquakes.isEmpty)
            _emptyCard(
              'No nearby earthquake events were returned by the current feed.',
            )
          else
            ...snapshot.earthquakes.map(
              (earthquake) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _earthquakeCard(earthquake),
              ),
            ),
          const SizedBox(height: 22),
          _sectionTitle('Official Disaster Alerts'),
          const SizedBox(height: 12),
          if (snapshot.alerts.isEmpty)
            _emptyCard('No alert entries were parsed from the NDMA pages.')
          else
            ...snapshot.alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _alertCard(alert),
              ),
            ),
          const SizedBox(height: 18),
          _privacyCard(),
        ],
      ),
    );
  }

  Widget _locationCard(LiveEmergencySnapshot snapshot) {
    final location = snapshot.location;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF3B3B).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B3B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFFF5555),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Your Current Location',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            location.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (location.address != null && location.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              location.address!,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${location.latitude.toStringAsFixed(6)}, '
            '${location.longitude.toStringAsFixed(6)}',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataStatusCard(LiveEmergencySnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: snapshot.fromCache
            ? const Color(0xFF30250F)
            : const Color(0xFF14351F),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: snapshot.fromCache
              ? const Color(0xFFF4B73C)
              : const Color(0xFF2E8B57),
        ),
      ),
      child: Row(
        children: [
          Icon(
            snapshot.fromCache
                ? Icons.cloud_off_rounded
                : Icons.cloud_done_rounded,
            color: snapshot.fromCache
                ? const Color(0xFFF4B73C)
                : Colors.greenAccent,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              snapshot.fromCache
                  ? 'Offline mode — showing the last successful live download'
                  : 'Live data — fetched using your current location',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _formatDateTime(snapshot.fetchedAt),
            style: const TextStyle(color: Color(0xFF777777), fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _weatherCard(WeatherSnapshot weather) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weather.temperature.round()}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weather.condition,
                        style: const TextStyle(
                          color: Color(0xFFF4B73C),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Feels like '
                        '${weather.apparentTemperature.round()}°C',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _weatherMetric(
                  Icons.water_drop_outlined,
                  'Humidity',
                  '${weather.humidity.round()}%',
                ),
              ),
              Expanded(
                child: _weatherMetric(
                  Icons.air_rounded,
                  'Wind',
                  '${weather.windSpeed.round()} km/h',
                ),
              ),
              Expanded(
                child: _weatherMetric(
                  Icons.umbrella_outlined,
                  'Precip.',
                  '${weather.precipitation.toStringAsFixed(1)} mm',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherMetric(IconData icon, String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFAAAAAA), size: 19),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF777777), fontSize: 10),
        ),
      ],
    );
  }

  Widget _contactCard(EmergencyContact contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF322323)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B3B).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Color(0xFFFF5555),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.number,
                  style: const TextStyle(
                    color: Color(0xFFF4B73C),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _call(contact.number),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  Widget _nearbyCard(NearbyPlace place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF4B73C).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _placeIcon(place.category),
              color: const Color(0xFFF4B73C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${place.category} • '
                  '${place.distanceLabel}',
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 11,
                  ),
                ),
                if (place.address != null && place.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    place.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (place.phone != null)
            IconButton(
              onPressed: () => _call(place.phone!),
              icon: const Icon(Icons.call_rounded, color: Color(0xFF7EE787)),
            ),
        ],
      ),
    );
  }

  IconData _placeIcon(String category) {
    switch (category) {
      case 'Hospital':
        return Icons.local_hospital_rounded;

      case 'Clinic':
        return Icons.medical_services_rounded;

      case 'Pharmacy':
        return Icons.local_pharmacy_rounded;

      case 'Police':
        return Icons.local_police_rounded;

      case 'Fire Station':
        return Icons.local_fire_department_rounded;

      case 'Ambulance':
        return Icons.emergency_rounded;

      case 'Shelter':
        return Icons.home_work_rounded;

      default:
        return Icons.location_on_rounded;
    }
  }

  Widget _earthquakeCard(EarthquakeSnapshot earthquake) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: earthquake.url == null ? null : () => _openUrl(earthquake.url!),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF191919),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFF2B2B2B)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B3B).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.vibration_rounded,
                color: Color(0xFFFF5555),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Magnitude '
                    '${earthquake.magnitude.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    earthquake.place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${earthquake.distanceKm.toStringAsFixed(0)} km away • '
                    '${_formatDateTime(earthquake.occurredAt)}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(OfficialAlert alert) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => _openUrl(alert.url),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF191919),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: const Color(0xFFF4B73C).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notification_important_rounded,
              color: Color(0xFFF4B73C),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    alert.source,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Color(0xFF666666)),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF858585),
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _privacyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: const Text(
        'OfflineLink uses your device location to request location-specific data. The latest successful result is stored locally so it can be viewed without Internet. V1 does not run continuous background location tracking.',
        style: TextStyle(color: Color(0xFF777777), fontSize: 11, height: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
