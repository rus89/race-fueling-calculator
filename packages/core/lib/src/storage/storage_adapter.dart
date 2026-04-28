// ABOUTME: Abstract interface for persisting and loading profiles, products, and plans.
// ABOUTME: Implemented by FileStorageAdapter (CLI) and will be implemented by a Flutter adapter later.
import '../models/athlete_profile.dart';
import '../models/product.dart';
import '../models/race_config.dart';

abstract class StorageAdapter {
  /// Root directory for persisted data. CLI commands use this to report where
  /// files live; platform adapters can return a sentinel path.
  String get baseDir;

  Future<AthleteProfile?> loadProfile();
  Future<void> saveProfile(AthleteProfile profile);
  Future<List<Product>> loadUserProducts();
  Future<void> saveUserProducts(List<Product> products);
  Future<RaceConfig?> loadPlan(String name);
  Future<void> savePlan(String name, RaceConfig config);
  Future<List<String>> listPlans();
  Future<void> deletePlan(String name);
}
