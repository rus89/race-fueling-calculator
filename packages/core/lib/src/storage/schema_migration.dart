// ABOUTME: Handles schema version checking and one-way migration of stored JSON data.
// ABOUTME: Applied automatically on load to upgrade older files to the current schema version.

class SchemaVersionException implements Exception {
  final String message;
  SchemaVersionException(this.message);

  @override
  String toString() => 'SchemaVersionException: $message';
}

Map<String, dynamic> validateSchemaVersion(
  Map<String, dynamic> json, {
  required int currentVersion,
}) {
  final version = json['schema_version'];
  if (version == null) {
    throw SchemaVersionException(
      'Missing schema_version field. Expected version $currentVersion.',
    );
  }
  if (version is! int) {
    throw SchemaVersionException(
      'schema_version must be an integer, got ${version.runtimeType}.',
    );
  }
  if (version > currentVersion) {
    throw SchemaVersionException(
      'Schema version $version is newer than supported version $currentVersion. '
      'Please update the app.',
    );
  }
  // TODO(migration): add migration logic for version < currentVersion
  return json;
}

/// Migrates a stored RaceConfig JSON map up to the current schema version.
///
/// Currently handles v1 -> v2:
/// - Drops the now-removed `isAidStationOnly` flag from every selected product
/// - Defaults `refill: []` on every aid station that lacks the key
/// - Bumps `schema_version` to 2
///
/// v2 input passes through unchanged. Missing `schema_version` is treated
/// as v1 (legacy files written before the field was introduced).
Map<String, dynamic> migrateRaceConfig(Map<String, dynamic> json) {
  final v = json['schema_version'] as int? ?? 1;
  if (v >= 2) return json;

  final out = Map<String, dynamic>.from(json);

  // Drop ProductSelection.isAidStationOnly
  if (out['selectedProducts'] is List) {
    out['selectedProducts'] = (out['selectedProducts'] as List).map((sel) {
      if (sel is Map<String, dynamic>) {
        return Map<String, dynamic>.from(sel)..remove('isAidStationOnly');
      }
      return sel;
    }).toList();
  }

  // Default refill: [] on aid stations
  if (out['aidStations'] is List) {
    out['aidStations'] = (out['aidStations'] as List).map((s) {
      if (s is Map<String, dynamic>) {
        final m = Map<String, dynamic>.from(s);
        m['refill'] ??= <String>[];
        return m;
      }
      return s;
    }).toList();
  }

  out['schema_version'] = 2;
  return out;
}
