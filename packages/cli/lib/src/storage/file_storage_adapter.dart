// ABOUTME: Implements StorageAdapter using local JSON files at ~/.race-fueling/.
// ABOUTME: Handles profile, products, and plans persistence for the CLI tool.
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:race_fueling_core/core.dart';

class FileStorageAdapter implements StorageAdapter {
  final String baseDir;

  FileStorageAdapter({String? baseDir})
      : baseDir = baseDir ??
            p.join(
              Platform.environment['HOME'] ?? '.',
              '.race-fueling',
            );

  String get _profilePath => p.join(baseDir, 'profile.json');
  String get _productsPath => p.join(baseDir, 'products.json');
  String get _plansDir => p.join(baseDir, 'plans');

  Future<void> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<AthleteProfile?> loadProfile() async {
    final file = File(_profilePath);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    validateSchemaVersion(json, currentVersion: 1);
    return AthleteProfile.fromJson(json);
  }

  @override
  Future<void> saveProfile(AthleteProfile profile) async {
    await _ensureDir(baseDir);
    final file = File(_profilePath);
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(profile.toJson()));
  }

  @override
  Future<List<Product>> loadUserProducts() async {
    final file = File(_productsPath);
    if (!await file.exists()) return [];
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    validateSchemaVersion(decoded, currentVersion: 1);
    final list = decoded['products'] as List<dynamic>;
    return list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveUserProducts(List<Product> products) async {
    await _ensureDir(baseDir);
    final json = {
      'schema_version': 1,
      'products': products.map((prod) => prod.toJson()).toList(),
    };
    final file = File(_productsPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  @override
  Future<RaceConfig?> loadPlan(String name) async {
    final file = File(p.join(_plansDir, '$name.json'));
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    validateSchemaVersion(json, currentVersion: 1);
    return RaceConfig.fromJson(json);
  }

  @override
  Future<void> savePlan(String name, RaceConfig config) async {
    await _ensureDir(_plansDir);
    final file = File(p.join(_plansDir, '$name.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config.toJson()));
  }

  @override
  Future<List<String>> listPlans() async {
    final dir = Directory(_plansDir);
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  @override
  Future<void> deletePlan(String name) async {
    final file = File(p.join(_plansDir, '$name.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
