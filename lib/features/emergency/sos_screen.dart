import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:offline_link/features/emergency/relay/installation_identity_service.dart';
import 'package:offline_link/features/emergency/relay/nearby_relay_controller.dart';
import 'package:offline_link/features/emergency/services/emergency_sync_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/connection_controller.dart';
import 'data/emergency_record.dart';
import 'emergency_repository.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    required this.connectionController,
    required this.emergencySyncController,
    required this.nearbyRelayController,
  });

  final ConnectionController connectionController;
  final EmergencySyncController emergencySyncController;
  final NearbyRelayController nearbyRelayController;


  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final EmergencyRepository _repository = EmergencyRepository();

  final InstallationIdentityService _identityService = InstallationIdentityService();

  final TextEditingController _noteController = TextEditingController();

  final TextEditingController _smsRecipientController = TextEditingController();


  EmergencyType _selectedType = EmergencyType.medical;

  List<EmergencyRecord> _recent = [];

  EmergencyRecord? _latestRecord;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }


  Future<void> _initialize() async {
    try {
      final recipient = await _repository.getSmsRecipient();

      final recent = await _repository.getRecentEmergencies();

      if (!mounted) {
        return;
      }

      _smsRecipientController.text = recipient ?? '';

      setState(() {
        _recent = recent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      _showMessage('Could not open the local emergency database.');
    }
  }

  Future<void> _relayAfterSave(
      EmergencyRecord record,
      ) async {
    try {
      final identity =
      await _identityService
          .getOrCreate();

      await widget
          .nearbyRelayController
          .sendEmergency(
        record,
        installationId:
        identity.installationId,
      );
    } catch (_) {
      // Local SQLite SOS remains safe.
    }
  }

  Future<void> _createSos() async {
    if (_saving) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      final recipient = _smsRecipientController.text.trim();

      if (recipient.isNotEmpty) {
        await _repository.saveSmsRecipient(recipient);
      }

      final record = await _repository.createEmergency(
        type: _selectedType,
        note: _noteController.text,
      );

      final recent = await _repository.getRecentEmergencies();

      if (!mounted) {
        return;
      }

      setState(() {
        _latestRecord = record;
        _recent = recent;
        _saving = false;
      });

      unawaited(
        _syncAfterSave(record.id),
      );

      unawaited(
        _relayAfterSave(record),
      );

      await _showSavedDialog(record);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage('SOS could not be saved: $error');
    }
  }


  Future<void> _syncAfterSave(
      String emergencyId,
      ) async {
    try {
      await widget.emergencySyncController
          .syncNow();

      final recent =
      await _repository
          .getRecentEmergencies();

      if (!mounted) {
        return;
      }

      EmergencyRecord? updated;

      for (final record in recent) {
        if (record.id == emergencyId) {
          updated = record;
          break;
        }
      }

      setState(() {
        _recent = recent;

        if (updated != null) {
          _latestRecord = updated;
        }
      });
    } catch (_) {
      // Keep the record pending.
    }
  }

  Future<void> _showSavedDialog(EmergencyRecord record) async {
    final hasSmsRecipient = _smsRecipientController.text.trim().isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF7EE787)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SOS saved locally',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            _savedDialogText(record),
            style: const TextStyle(color: Color(0xFFBDBDBD), height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Saved only'),
            ),
            if (hasSmsRecipient)
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _openSms(record);
                },
                icon: const Icon(Icons.sms_rounded, size: 18),
                label: const Text('Open SMS'),
              ),
          ],
        );
      },
    );
  }

  String _savedDialogText(EmergencyRecord record) {
    final buffer = StringBuffer();

    buffer.writeln('Your emergency record is now stored on this phone.');

    buffer.writeln();

    switch (record.locationSource) {
      case EmergencyLocationSource.current:
        buffer.writeln('Current device location was captured.');
        break;

      case EmergencyLocationSource.lastKnown:
        buffer.writeln('A last-known device location was used.');
        break;

      case EmergencyLocationSource.unavailable:
        buffer.writeln('A device location was not available.');
        break;
    }

    buffer.writeln();

    buffer.writeln(
      'The app has NOT automatically contacted emergency services.',
    );

    return buffer.toString();
  }

  Future<void> _openSms(EmergencyRecord record) async {
    final number = _smsRecipientController.text.trim();

    if (number.isEmpty) {
      _showMessage('Add an SMS recipient first.');
      return;
    }

    final body = _buildSmsBody(record);

    final uri = Uri(
      scheme: 'sms',
      path: number,
      query: _encodeQueryParameters({'body': body}),
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched) {
        _showMessage('The phone could not open the SMS app.');
        return;
      }

      _showMessage(
        'SMS composer opened. Review it and press Send.',
      );
    } catch (_) {
      _showMessage('Could not open the SMS composer.');
    }
  }

  String _buildSmsBody(EmergencyRecord record) {
    final buffer = StringBuffer();

    buffer.writeln('OFFLINELINK SOS');

    buffer.writeln('Type: ${record.type.label}');

    buffer.writeln('Time: ${_formatDateTime(record.createdAt)}');

    if (record.latitude != null && record.longitude != null) {
      buffer.writeln(
        'Location: '
        '${record.latitude!.toStringAsFixed(6)}, '
        '${record.longitude!.toStringAsFixed(6)}',
      );

      if (record.accuracyMeters != null) {
        buffer.writeln(
          'Accuracy: '
          '${record.accuracyMeters!.toStringAsFixed(0)} m',
        );
      }

      buffer.writeln(
        'Map: '
        'https://maps.google.com/?q='
        '${record.latitude},${record.longitude}',
      );
    } else {
      buffer.writeln('Location: unavailable');
    }

    if (record.address != null && record.address!.trim().isNotEmpty) {
      buffer.writeln('Address: ${record.address}');
    }

    if (record.note != null && record.note!.trim().isNotEmpty) {
      buffer.writeln('Message: ${record.note}');
    }

    return buffer.toString().trim();
  }

  String _encodeQueryParameters(Map<String, String> parameters) {
    return parameters.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  Future<void> _saveRecipient() async {
    final number = _smsRecipientController.text.trim();

    if (number.isEmpty) {
      _showMessage('Enter a phone number first.');
      return;
    }

    await _repository.saveSmsRecipient(number);

    _showMessage('Emergency SMS recipient saved locally.');
  }

  Future<void> _openLocationSettings() async {
    try {
      final opened = await Geolocator.openLocationSettings();

      if (!opened) {
        _showMessage('Could not open Location settings.');
      }
    } catch (_) {
      _showMessage('Could not open Location settings.');
    }
  }

  String _formatDateTime(DateTime date) {
    final value = date.toLocal();

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/${value.month.toString().padLeft(2, '0')}/'
        '${value.year} $hour:$minute';
  }

  String _locationLabel(EmergencyRecord record) {
    switch (record.locationSource) {
      case EmergencyLocationSource.current:
        return 'Current GPS location';

      case EmergencyLocationSource.lastKnown:
        return 'Last-known GPS location';

      case EmergencyLocationSource.unavailable:
        return 'Location unavailable';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final online = widget.connectionController.isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
        children: [
          _connectionCard(online),
          const SizedBox(height: 16),
          _warningCard(),
          const SizedBox(height: 24),
          _sectionTitle('Emergency type'),
          const SizedBox(height: 12),
          _typeSelector(),
          const SizedBox(height: 24),
          _noteField(),
          const SizedBox(height: 24),
          _smsRecipientCard(),
          const SizedBox(height: 26),
          _sosButton(),
          const SizedBox(height: 14),
          const Text(
            'Your SOS is saved locally before any communication attempt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          if (_latestRecord != null) ...[
            const SizedBox(height: 28),
            _latestRecordCard(_latestRecord!),
          ],
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 28),
            _sectionTitle('Local emergency history'),
            const SizedBox(height: 12),
            ..._recent.take(5).map(_historyCard),
          ],
        ],
      ),
    );
  }

  Widget _connectionCard(bool online) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: online ? const Color(0xFF14351F) : const Color(0xFF30250F),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: online ? const Color(0xFF2E8B57) : const Color(0xFFF4B73C),
        ),
      ),
      child: Row(
        children: [
          Icon(
            online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: online ? Colors.greenAccent : const Color(0xFFF4B73C),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              online
                  ? 'Internet available — SOS will still be saved locally first.'
                  : 'Offline — SOS can still be saved on this phone.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF241010),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF3B3B).withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5A5A), size: 27),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Emergency SOS creates a local emergency record. '
              'It does not silently send an emergency alert. '
              'SMS fallback opens your phone messaging app so you can review and send the message.',
              style: TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EmergencyType.values
          .map(
            (type) => ChoiceChip(
              selected: _selectedType == type,
              label: Text(type.label),
              onSelected: (_) {
                setState(() {
                  _selectedType = type;
                });
              },
            ),
          )
          .toList(),
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('What happened?'),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Example: Two people injured in a road accident.',
            hintStyle: const TextStyle(color: Color(0xFF666666)),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFFF3B3B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _smsRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sms_rounded, color: Color(0xFFF4B73C)),
              SizedBox(width: 10),
              Text(
                'SMS fallback',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Save a trusted phone number. After an SOS is created, OfflineLink can open an SMS with the emergency details and location.',
            style: TextStyle(
              color: Color(0xFF808080),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _smsRecipientController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '+92 3XX XXXXXXX',
              hintStyle: const TextStyle(color: Color(0xFF626262)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              prefixIcon: const Icon(
                Icons.phone_rounded,
                color: Color(0xFF888888),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _saveRecipient,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save recipient'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sosButton() {
    return SizedBox(
      height: 76,
      child: FilledButton(
        onPressed: _saving ? null : _createSos,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF3B3B),
          disabledBackgroundColor: const Color(0xFF5A2020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sos_rounded, size: 32),
                  SizedBox(width: 12),
                  Text(
                    'CREATE SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _latestRecordCard(EmergencyRecord record) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E8B57)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest SOS',
            style: TextStyle(
              color: Color(0xFF7EE787),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            record.type.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _locationLabel(record),
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
          ),
          if (record.latitude != null && record.longitude != null) ...[
            const SizedBox(height: 6),
            Text(
              '${record.latitude!.toStringAsFixed(6)}, '
              '${record.longitude!.toStringAsFixed(6)}',
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_smsRecipientController.text.trim().isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _openSms(record),
              icon: const Icon(Icons.sms_rounded),
              label: const Text('Open SMS fallback'),
            ),
        ],
      ),
    );
  }

  Widget _historyCard(EmergencyRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B3B).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: Color(0xFFFF5555),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.type.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(record.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            record.syncState == EmergencySyncState.pending
                ? 'Pending'
                : record.syncState.name,
            style: const TextStyle(
              color: Color(0xFFF4B73C),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _smsRecipientController.dispose();
    super.dispose();
  }
}
