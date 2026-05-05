// ABOUTME: shared_preferences-backed PlanStorage; one JSON blob under a key.
// ABOUTME: Works on web (localStorage), mobile (NSUserDefaults / Prefs), desktop.
import 'dart:convert';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:race_fueling_core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/planner_state.dart';
import 'plan_storage.dart';

class PlanStorageLocal implements PlanStorage {
  static const _key = 'bonk_v1.working_plan';
  static const _backupKey = '$_key.bak';

  @override
  Future<PlannerState?> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on MissingPluginException catch (e, st) {
      throw PlanStorageException(
        'Failed to initialize storage',
        cause: e,
        causeStack: st,
      );
    }
    final raw = prefs.getString(_key);
    if (raw == null) return null; // genuinely empty drive — never saved.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw PlanStorageException(
          'Stored plan is not a JSON object',
          rawBytes: raw,
        );
      }
      final json = decoded;
      final rawCfg = json['raceConfig'];
      if (rawCfg is! Map<String, dynamic>) {
        throw PlanStorageException(
          'Stored plan is missing or has malformed raceConfig',
          rawBytes: raw,
        );
      }
      // Validate schema version against current support window before migrating
      // — this surfaces "blob is from a newer app" cleanly.
      validateSchemaVersion(rawCfg, currentVersion: 2);
      final migrated = {...json, 'raceConfig': migrateRaceConfig(rawCfg)};
      return PlannerState.fromJson(migrated);
    } on PlanStorageException {
      rethrow;
    } on FormatException catch (e, st) {
      throw PlanStorageException(
        'Stored plan JSON is malformed',
        cause: e,
        causeStack: st,
        rawBytes: raw,
      );
    } on SchemaVersionException catch (e, st) {
      throw PlanStorageException(
        'Stored plan schema version is unsupported',
        cause: e,
        causeStack: st,
        rawBytes: raw,
      );
    } on TypeError catch (e, st) {
      // fromJson cast failures (e.g. raceConfig is a string).
      throw PlanStorageException(
        'Stored plan has wrong shape',
        cause: e,
        causeStack: st,
        rawBytes: raw,
      );
    } on ArgumentError catch (e, st) {
      // Required model fields missing or out of range during construction.
      throw PlanStorageException(
        'Stored plan failed validation',
        cause: e,
        causeStack: st,
        rawBytes: raw,
      );
    }
    // Errors not in this list (StackOverflowError, OutOfMemoryError, asserts)
    // indicate programming bugs and propagate to crash the app.
  }

  @override
  Future<void> save(PlannerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await _backupCorruptedBytesIfPresent(prefs);
    // TODO(PB-DATA-2): handle quota exceeded on web (DOMException) — fail
    // gracefully to surface a "storage full" banner instead of crashing.
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Backs up the prior _key value to _backupKey on the first save that follows
  // an unreadable blob. Mirrors the CLI's `<name>.json.v1.bak` convention so
  // a corrupted plan is recoverable post-mortem. No-op when the prior bytes
  // parse cleanly (i.e. this isn't a recovery save).
  Future<void> _backupCorruptedBytesIfPresent(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      jsonDecode(raw); // structural parse only — semantic checks are upstream.
      return;
    } on FormatException {
      if (prefs.getString(_backupKey) != null) return; // never overwrite.
      // TODO(PB-DATA-2): consider attaching an integrity tag (timestamp +
      // checksum) when restoring from backup so users can confirm provenance.
      await prefs.setString(_backupKey, raw);
    }
  }
}
