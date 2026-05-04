// ABOUTME: shared_preferences-backed PlanStorage; one JSON blob under a key.
// ABOUTME: Works on web (localStorage), mobile (NSUserDefaults / Prefs), desktop.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/planner_state.dart';
import 'plan_storage.dart';

class PlanStorageLocal implements PlanStorage {
  static const _key = 'bonk_v1.working_plan';

  @override
  Future<PlannerState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PlannerState.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(PlannerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
