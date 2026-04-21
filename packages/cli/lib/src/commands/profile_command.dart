// ABOUTME: ProfileCommand — 'fuel profile setup/show/set' subcommands that
// ABOUTME: read and write the athlete profile through a StorageAdapter.
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:race_fueling_core/core.dart';

import '../cli/errors.dart';
import '../cli/exit_codes.dart';
import '../prompts/interactive.dart';
import '../storage/file_storage_adapter.dart';

/// Probes whether stdin is connected to a terminal. Defaults to
/// `stdin.hasTerminal`; tests inject a deterministic value.
typedef IsTtyProbe = bool Function();

bool _defaultIsTty() => stdin.hasTerminal;

class ProfileCommand extends Command<void> {
  ProfileCommand(
    StorageAdapter storage, {
    IsTtyProbe isTty = _defaultIsTty,
  }) {
    addSubcommand(_ProfileSetupCommand(storage, isTty: isTty));
    addSubcommand(_ProfileShowCommand(storage));
    addSubcommand(_ProfileSetCommand(storage));
  }

  @override
  final String name = 'profile';

  @override
  final String description = 'Manage your athlete profile';
}

/// Parses a tolerance flag, translating parse failures into a UsageException
/// with an actionable message. Returns null if the flag was not supplied.
double? _parseTolerance(ArgResults results) {
  final raw = results['tolerance'] as String?;
  if (raw == null) return null;
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    exitWith(kExitUsage, 'Expected a number for --tolerance, got "$raw"');
    throw _FlagParseFailure();
  }
  return parsed;
}

double? _parseWeight(ArgResults results) {
  final raw = results['weight'] as String?;
  if (raw == null) return null;
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    exitWith(kExitUsage, 'Expected a number for --weight, got "$raw"');
    throw _FlagParseFailure();
  }
  return parsed;
}

UnitSystem? _parseUnits(ArgResults results) {
  final raw = results['units'] as String?;
  if (raw == null) return null;
  return switch (raw) {
    'metric' => UnitSystem.metric,
    'imperial' => UnitSystem.imperial,
    _ => throw UsageException(
        '--units must be one of: metric, imperial',
        'Got "$raw".',
      ),
  };
}

/// Internal sentinel thrown when a flag parser already reported the failure
/// via `exitWith`; catchers ignore it and return.
class _FlagParseFailure implements Exception {}

class _ProfileSetupCommand extends Command<void> {
  _ProfileSetupCommand(this._storage, {required IsTtyProbe isTty})
      : _isTty = isTty {
    argParser
      ..addOption(
        'tolerance',
        help: 'Gut tolerance in grams of carbs per hour (required).',
      )
      ..addOption(
        'units',
        help: 'Unit system (metric or imperial, required).',
      )
      ..addOption(
        'weight',
        help: 'Body weight in kg (optional, enables caffeine safety).',
      )
      ..addFlag(
        'no-weight',
        help: 'Explicitly skip the body weight prompt.',
        negatable: false,
      );
  }

  final StorageAdapter _storage;
  final IsTtyProbe _isTty;

  @override
  final String name = 'setup';

  @override
  final String description = 'Create a new athlete profile';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('setup invoked without parsed arguments');
    }

    final double? tolerance;
    final UnitSystem? units;
    final double? weight;
    try {
      tolerance = _parseTolerance(results);
      units = _parseUnits(results);
      weight = _parseWeight(results);
    } on _FlagParseFailure {
      return;
    }

    final skipWeight = results['no-weight'] as bool;

    final missing = <String>[
      if (tolerance == null) '--tolerance',
      if (units == null) '--units',
      if (weight == null && !skipWeight) '--weight',
    ];

    final double resolvedTolerance;
    final UnitSystem resolvedUnits;
    final double? resolvedWeight;

    if (missing.isEmpty) {
      resolvedTolerance = tolerance!;
      resolvedUnits = units!;
      resolvedWeight = weight;
    } else {
      if (!_isTty()) {
        exitWith(
          kExitNoInput,
          'No TTY; pass --tolerance/--units/--weight flags.',
        );
        return;
      }
      try {
        final promptedTolerance =
            tolerance ?? promptDouble('Gut tolerance (g/hr)', min: 1, max: 200);
        if (promptedTolerance == null) {
          exitWith(kExitNoInput, 'Tolerance is required.');
          return;
        }
        resolvedTolerance = promptedTolerance;
        resolvedUnits = units ??
            promptChoice<UnitSystem>(
              'Units',
              UnitSystem.values,
              describe: (u) => u.name,
            );
        if (skipWeight || weight != null) {
          resolvedWeight = weight;
        } else {
          resolvedWeight = promptDouble(
            'Body weight (kg, optional — blank to skip)',
            min: 20,
            max: 250,
          );
        }
      } on PromptAbortedException catch (e) {
        exitWith(kExitUsage, e.message);
        return;
      } on NoTerminalException catch (e) {
        exitWith(kExitNoInput, e.message);
        return;
      }
    }

    try {
      final profile = AthleteProfile(
        gutToleranceGPerHr: resolvedTolerance,
        unitSystem: resolvedUnits,
        bodyWeightKg: resolvedWeight,
      );
      await _storage.saveProfile(profile);
      stdout.writeln('Profile saved.');
    } on AssertionError catch (e) {
      exitWith(kExitData, 'Invalid profile: ${e.message}');
    } on FormatException catch (e) {
      exitWith(kExitData, 'Invalid profile: ${e.message}');
    } on FileSystemException catch (e) {
      exitWith(kExitData, 'File error: ${e.message} (${e.path ?? ''})');
    }
  }
}

class _ProfileShowCommand extends Command<void> {
  _ProfileShowCommand(this._storage);

  final StorageAdapter _storage;

  @override
  final String name = 'show';

  @override
  final String description = 'Print the stored athlete profile';

  @override
  Future<void> run() async {
    try {
      final profile = await _storage.loadProfile();
      if (profile == null) {
        exitWith(
          kExitData,
          "No profile found. Run 'fuel profile setup' first.",
        );
        return;
      }
      stdout.writeln('Gut tolerance: ${profile.gutToleranceGPerHr} g/hr');
      stdout.writeln('Units: ${profile.unitSystem.name}');
      stdout.writeln(
        'Body weight: ${profile.bodyWeightKg?.toString() ?? '(not set)'} kg',
      );
      final baseDir = _storage is FileStorageAdapter ? _storage.baseDir : null;
      if (baseDir != null) {
        stdout.writeln('Config file: ${p.join(baseDir, 'profile.json')}');
      }
    } on FormatException catch (e) {
      exitWith(kExitData, 'Invalid data: ${e.message}');
    } on FileSystemException catch (e) {
      exitWith(kExitData, 'File error: ${e.message} (${e.path ?? ''})');
    }
  }
}

class _ProfileSetCommand extends Command<void> {
  _ProfileSetCommand(this._storage) {
    argParser
      ..addOption('tolerance', help: 'New gut tolerance (g/hr)')
      ..addOption(
        'units',
        help: 'New unit system (metric or imperial)',
      )
      ..addOption('weight', help: 'New body weight (kg)');
  }

  final StorageAdapter _storage;

  @override
  final String name = 'set';

  @override
  final String description = 'Update individual fields on the stored profile';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('set invoked without parsed arguments');
    }

    final double? tolerance;
    final UnitSystem? units;
    final double? weight;
    try {
      tolerance = _parseTolerance(results);
      units = _parseUnits(results);
      weight = _parseWeight(results);
    } on _FlagParseFailure {
      return;
    }

    final AthleteProfile? current;
    try {
      current = await _storage.loadProfile();
    } on FormatException catch (e) {
      exitWith(kExitData, 'Invalid data: ${e.message}');
      return;
    } on FileSystemException catch (e) {
      exitWith(kExitData, 'File error: ${e.message} (${e.path ?? ''})');
      return;
    }

    if (current == null) {
      exitWith(
        kExitData,
        "No profile found. Run 'fuel profile setup' first.",
      );
      return;
    }

    try {
      final updated = current.copyWith(
        gutToleranceGPerHr: tolerance,
        unitSystem: units,
        bodyWeightKg: weight,
      );
      await _storage.saveProfile(updated);
      stdout.writeln('Profile updated.');
    } on AssertionError catch (e) {
      exitWith(kExitData, 'Invalid profile: ${e.message}');
    } on FormatException catch (e) {
      exitWith(kExitData, 'Invalid profile: ${e.message}');
    } on FileSystemException catch (e) {
      exitWith(kExitData, 'File error: ${e.message} (${e.path ?? ''})');
    }
  }
}
