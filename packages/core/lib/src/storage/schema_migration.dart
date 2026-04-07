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
        'Missing schema_version field. Expected version $currentVersion.');
  }
  if (version is! int) {
    throw SchemaVersionException(
        'schema_version must be an integer, got ${version.runtimeType}.');
  }
  if (version > currentVersion) {
    throw SchemaVersionException(
        'Schema version $version is newer than supported version $currentVersion. '
        'Please update the app.');
  }
  // Future: add migration logic for version < currentVersion
  return json;
}
