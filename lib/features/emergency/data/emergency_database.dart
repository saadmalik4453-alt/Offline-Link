import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../relay/relay_packet.dart';
import 'emergency_record.dart';

class EmergencyDatabase {
  EmergencyDatabase._();

  static final EmergencyDatabase instance =
  EmergencyDatabase._();

  static const String _databaseName =
      'offline_link.db';

  static const int _databaseVersion = 3;

  static const String _emergenciesTable =
      'emergencies';

  static const String _relayTable =
      'relay_packets';

  static const String _settingsTable =
      'settings';

  static const String _smsRecipientKey =
      'sms_recipient';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databaseDirectory =
    await getDatabasesPath();

    final databasePath = join(
      databaseDirectory,
      _databaseName,
    );

    return openDatabase(
      databasePath,
      version: _databaseVersion,

      onCreate: (
          Database db,
          int version,
          ) async {
        await _createEmergenciesTable(db);
        await _createSettingsTable(db);
        await _createRelayTable(db);
      },

      onUpgrade: (
          Database db,
          int oldVersion,
          int newVersion,
          ) async {
        if (oldVersion < 2) {
          await _migrateToVersion2(db);
        }

        if (oldVersion < 3) {
          await _createRelayTable(db);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TABLE CREATION
  // ---------------------------------------------------------------------------

  Future<void> _createEmergenciesTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE $_emergenciesTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        note TEXT,
        latitude REAL,
        longitude REAL,
        accuracy_meters REAL,
        location_timestamp INTEGER,
        address TEXT,
        location_source TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sync_state TEXT NOT NULL,
        sms_composer_opened_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_emergencies_sync_state
      ON $_emergenciesTable(sync_state)
    ''');

    await db.execute('''
      CREATE INDEX idx_emergencies_created_at
      ON $_emergenciesTable(created_at)
    ''');
  }

  Future<void> _createSettingsTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRelayTable(
      Database db,
      ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_relayTable (
        packet_id TEXT PRIMARY KEY,
        origin_emergency_id TEXT NOT NULL,
        origin_installation_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        forwarded_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_relay_origin_emergency
      ON $_relayTable(origin_emergency_id)
    ''');
  }

  // ---------------------------------------------------------------------------
  // DATABASE MIGRATION
  // ---------------------------------------------------------------------------

  Future<void> _migrateToVersion2(
      Database db,
      ) async {
    await db.execute('''
      ALTER TABLE $_emergenciesTable
      ADD COLUMN sms_composer_opened_at INTEGER
    ''');

    await _createSettingsTable(db);
  }

  // ---------------------------------------------------------------------------
  // EMERGENCY RECORDS
  // ---------------------------------------------------------------------------

  Future<void> insert(
      EmergencyRecord record,
      ) async {
    final db = await database;

    await db.insert(
      _emergenciesTable,
      record.toMap(),
      conflictAlgorithm:
      ConflictAlgorithm.ignore,
    );
  }

  Future<EmergencyRecord?> getById(
      String id,
      ) async {
    final db = await database;

    final rows = await db.query(
      _emergenciesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return EmergencyRecord.fromMap(
      rows.first,
    );
  }

  Future<List<EmergencyRecord>>
  getRecent({
    int limit = 50,
  }) async {
    final db = await database;

    final rows = await db.query(
      _emergenciesTable,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows
        .map(
      EmergencyRecord.fromMap,
    )
        .toList();
  }

  Future<List<EmergencyRecord>>
  getPendingSync() async {
    final db = await database;

    final rows = await db.query(
      _emergenciesTable,
      where: 'sync_state = ?',
      whereArgs: [
        EmergencySyncState.pending.name,
      ],
      orderBy: 'created_at ASC',
    );

    return rows
        .map(
      EmergencyRecord.fromMap,
    )
        .toList();
  }

  Future<void> markSynced(
      String id,
      ) async {
    final db = await database;

    await db.update(
      _emergenciesTable,
      {
        'sync_state':
        EmergencySyncState.synced.name,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pendingCount() async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM $_emergenciesTable
      WHERE sync_state = ?
      ''',
      [
        EmergencySyncState.pending.name,
      ],
    );

    return Sqflite.firstIntValue(
      result,
    ) ??
        0;
  }

  // ---------------------------------------------------------------------------
  // SMS
  // ---------------------------------------------------------------------------

  Future<String?> getSmsRecipient() async {
    return getSetting(
      _smsRecipientKey,
    );
  }

  Future<void> saveSmsRecipient(
      String phoneNumber,
      ) async {
    final cleaned =
    phoneNumber.trim();

    if (cleaned.isEmpty) {
      throw ArgumentError(
        'Phone number cannot be empty.',
      );
    }

    await setSetting(
      _smsRecipientKey,
      cleaned,
    );
  }

  Future<void> markSmsComposerOpened(
      String emergencyId,
      ) async {
    final db = await database;

    await db.update(
      _emergenciesTable,
      {
        'sms_composer_opened_at':
        DateTime.now()
            .toUtc()
            .millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [emergencyId],
    );
  }

  // ---------------------------------------------------------------------------
  // GENERIC SETTINGS
  // ---------------------------------------------------------------------------

  Future<String?> getSetting(
      String key,
      ) async {
    final db = await database;

    final rows = await db.query(
      _settingsTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final value =
    rows.first['value'];

    if (value == null) {
      return null;
    }

    return value.toString();
  }

  Future<void> setSetting(
      String key,
      String value,
      ) async {
    final db = await database;

    await db.insert(
      _settingsTable,
      {
        'key': key,
        'value': value,
      },
      conflictAlgorithm:
      ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(
      String key,
      ) async {
    final db = await database;

    await db.delete(
      _settingsTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // ---------------------------------------------------------------------------
  // NEARBY RELAY
  // ---------------------------------------------------------------------------

  Future<bool> relayPacketExists(
      String packetId,
      ) async {
    final db = await database;

    final rows = await db.query(
      _relayTable,
      columns: ['packet_id'],
      where: 'packet_id = ?',
      whereArgs: [packetId],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<void> saveRelayPacket(
      RelayPacket packet,
      ) async {
    final db = await database;

    await db.insert(
      _relayTable,
      {
        'packet_id':
        packet.packetId,
        'origin_emergency_id':
        packet.originEmergencyId,
        'origin_installation_id':
        packet.originInstallationId,
        'payload':
        jsonEncode(
          packet.toMap(),
        ),
        'received_at':
        DateTime.now()
            .toUtc()
            .millisecondsSinceEpoch,
      },
      conflictAlgorithm:
      ConflictAlgorithm.ignore,
    );
  }

  Future<List<RelayPacket>>
  getUnexpiredRelayPackets() async {
    final db = await database;

    final rows = await db.query(
      _relayTable,
      orderBy: 'received_at DESC',
    );

    final packets =
    <RelayPacket>[];

    for (final row in rows) {
      try {
        final raw =
        row['payload'] as String;

        final decoded =
        jsonDecode(raw);

        if (decoded
        is! Map<String, dynamic>) {
          continue;
        }

        final packet =
        RelayPacket.fromMap(
          decoded,
        );

        if (!packet.isExpired) {
          packets.add(packet);
        }
      } catch (_) {
        // Ignore malformed relay
        // records instead of breaking
        // the whole relay queue.
      }
    }

    return packets;
  }

  Future<void> markRelayForwarded(
      String packetId,
      ) async {
    final db = await database;

    await db.update(
      _relayTable,
      {
        'forwarded_at':
        DateTime.now()
            .toUtc()
            .millisecondsSinceEpoch,
      },
      where: 'packet_id = ?',
      whereArgs: [packetId],
    );
  }

  Future<int> relayPacketCount() async {
    final db = await database;

    final result =
    await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM $_relayTable
      ''',
    );

    return Sqflite.firstIntValue(
      result,
    ) ??
        0;
  }

  Future<void>
  deleteExpiredRelayPackets() async {
    final db = await database;

    final rows = await db.query(
      _relayTable,
      columns: [
        'packet_id',
        'payload',
      ],
    );

    for (final row in rows) {
      try {
        final raw =
        row['payload'] as String;

        final decoded =
        jsonDecode(raw);

        if (decoded
        is! Map<String, dynamic>) {
          await db.delete(
            _relayTable,
            where: 'packet_id = ?',
            whereArgs: [
              row['packet_id'],
            ],
          );

          continue;
        }

        final packet =
        RelayPacket.fromMap(
          decoded,
        );

        if (packet.isExpired) {
          await db.delete(
            _relayTable,
            where: 'packet_id = ?',
            whereArgs: [
              packet.packetId,
            ],
          );
        }
      } catch (_) {
        await db.delete(
          _relayTable,
          where: 'packet_id = ?',
          whereArgs: [
            row['packet_id'],
          ],
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DATABASE CLOSE
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    final db = _database;

    if (db == null) {
      return;
    }

    await db.close();

    _database = null;
  }
}