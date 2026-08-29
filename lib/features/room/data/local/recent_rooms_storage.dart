import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final recentRoomsStorageProvider = Provider<RecentRoomsStorage>(
  (ref) => const RecentRoomsStorage(),
);

class RecentRoomEntry {
  const RecentRoomEntry({required this.roomId, required this.lastVisitedAt});

  final String roomId;
  final DateTime lastVisitedAt;

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'lastVisitedAt': lastVisitedAt.toUtc().toIso8601String(),
    };
  }

  static RecentRoomEntry? fromJson(Map<String, dynamic> json) {
    final roomId = json['roomId'] as String?;

    final rawLastVisitedAt = json['lastVisitedAt'] as String?;

    if (roomId == null || roomId.isEmpty || rawLastVisitedAt == null) {
      return null;
    }

    final lastVisitedAt = DateTime.tryParse(rawLastVisitedAt);

    if (lastVisitedAt == null) {
      return null;
    }

    return RecentRoomEntry(roomId: roomId, lastVisitedAt: lastVisitedAt);
  }
}

class RecentRoomsStorage {
  const RecentRoomsStorage();

  static const _keyPrefix = 'linsy_recent_rooms_';

  String _key(String userId) {
    return '$_keyPrefix$userId';
  }

  Future<List<RecentRoomEntry>> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();

    final raw = preferences.getString(_key(userId));

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      final entries = <RecentRoomEntry>[];

      for (final value in decoded) {
        if (value is! Map) {
          continue;
        }

        final entry = RecentRoomEntry.fromJson(
          Map<String, dynamic>.from(value),
        );

        if (entry != null) {
          entries.add(entry);
        }
      }

      entries.sort((a, b) => b.lastVisitedAt.compareTo(a.lastVisitedAt));

      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> remember({
    required String userId,
    required String roomId,
  }) async {
    final entries = await load(userId);

    entries.removeWhere((entry) => entry.roomId == roomId);

    entries.insert(
      0,
      RecentRoomEntry(roomId: roomId, lastVisitedAt: DateTime.now().toUtc()),
    );

    await _save(userId, entries);
  }

  Future<void> keepOnly({
    required String userId,
    required Set<String> roomIds,
  }) async {
    final entries = await load(userId);

    final filtered = entries
        .where((entry) => roomIds.contains(entry.roomId))
        .toList();

    await _save(userId, filtered);
  }

  Future<void> _save(String userId, List<RecentRoomEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();

    if (entries.isEmpty) {
      await preferences.remove(_key(userId));

      return;
    }

    final raw = jsonEncode(entries.map((entry) => entry.toJson()).toList());

    await preferences.setString(_key(userId), raw);
  }
}
