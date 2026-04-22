// ABOUTME: ProfileCommand — 'fuel profile setup/show/set' subcommands that
// ABOUTME: read and write the athlete profile through a StorageAdapter.
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:race_fueling_core/core.dart';

import '../cli/errors.dart';
import '../cli/exit_codes.dart';
import '../cli/tty.dart';
import '../prompts/interactive.dart';

class ProfileCommand extends Command<void> {
  ProfileCommand(
    StorageAdapter storage, {
    IsTtyProbe isTty = defaultIsTty,
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

/// Parses a tolerance flag, throwing [UsageException] on parse failure.
/// Returns null if the flag was not supplied.
double? _parseTolerance(ArgResults results) {
  final raw = results['tolerance'] as String?;
  if (raw == null) return null;
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    throw UsageException(
      'Expected a number for --tolerance, got "$raw"',
      'Pass --tolerance <number between 1 and 200>.',
    );
  }
  return parsed;
}

double? _parseWeight(ArgResults results) {
  final raw = results['weight'] as String?;
  if (raw == null) return null;
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    throw UsageException(
      'Expected a number for --weight, got "$raw"',
      'Pass --weight <body weight in kg>.',
    );
  }
  return parsed;
}

UnitSystem? _parseUnits(ArgResults results) {
  final raw = results['units'] as String?;
  if (raw == null) return null;
  // Imperial is accepted in the core model but not yet wired through the
  // CLI; reject explicitly so nobody silently gets a metric fallback.
  return switch (raw) {
    'metric' => UnitSystem.metric,
    'imperial' => throw UsageException(
        'Imperial units are not yet supported; use --units metric for v1.',
        'Imperial support is planned for a future release.',
      ),
    _ => throw UsageException(
        '--units must be one of: metric',
        'Got "$raw".',
      ),
  };
}

class _ProfileSetupCommand extends Command<void> {
  _ProfileSetupCommand(this._storage, {required IsTtyProbe isTty})
      : _isTty = isTty {
    argParser
      ..addOption(
        'tolerance',
        help: 'Gut tolerance in g/hr (1–200).',
      )
      ..addOption(
        'units',
        help: "Unit system for body weight. Only 'metric' is supported "
            'in v1.',
      )
      ..addOption(
        'weight',
        help: 'Body weight in kg (optional, improves caffeine safety checks).',
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

    final tolerance = _parseTolerance(results);
    final units = _parseUnits(results);
    final weight = _parseWeight(results);

    // --weight is always optional; a missing value simply means the user
    // didn't record their weight. The non-TTY path skips it silently.
    final missing = <String>[
      if (tolerance == null) '--tolerance',
      if (units == null) '--units',
    ];

    final double resolvedTolerance;
    final UnitSystem resolvedUnits;
    final double? resolvedWeight;

    if (tolerance != null && units != null) {
      resolvedTolerance = tolerance;
      resolvedUnits = units;
      resolvedWeight = weight;
    } else {
      if (!_isTty()) {
        exitWith(
          kExitNoInput,
          'No TTY; pass ${missing.join('/')} flag${missing.length == 1 ? '' : 's'}.',
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
        // Interactive units prompt skips the question: metric is the only
        // supported value in v1, so we tell the user and move on instead of
        // forcing them to answer a single-option prompt.
        if (units == null) {
          stderr.writeln(
            'Using metric units (imperial coming in a future version).',
          );
        }
        resolvedUnits = units ?? UnitSystem.metric;
        if (weight != null) {
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

    await withFriendlyErrors(() async {
      final profile = AthleteProfile.fromJson({
        'gutToleranceGPerHr': resolvedTolerance,
        'unitSystem': resolvedUnits.name,
        if (resolvedWeight != null) 'bodyWeightKg': resolvedWeight,
        'schema_version': 1,
      });
      await _storage.saveProfile(profile);
    });
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
    await withFriendlyErrors(() async {
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
      stdout.writeln(
        'Config file: ${p.join(_storage.baseDir, 'profile.json')}',
      );
    });
  }
}

class _ProfileSetCommand extends Command<void> {
  _ProfileSetCommand(this._storage) {
    argParser
      ..addOption('tolerance', help: 'New gut tolerance in g/hr (1–200).')
      ..addOption(
        'units',
        help: "New unit system. Only 'metric' is supported in v1.",
      )
      ..addOption('weight', help: 'New body weight in kg.');
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

    final tolerance = _parseTolerance(results);
    final units = _parseUnits(results);
    final weight = _parseWeight(results);

    if (tolerance == null && units == null && weight == null) {
      exitWith(
        kExitUsage,
        'Nothing to update. Pass at least one of: --tolerance, --units, --weight.',
      );
      return;
    }

    await withFriendlyErrors(() async {
      final current = await _storage.loadProfile();
      if (current == null) {
        exitWith(
          kExitData,
          "No profile found. Run 'fuel profile setup' first.",
        );
        return;
      }

      final merged = <String, dynamic>{
        'gutToleranceGPerHr': tolerance ?? current.gutToleranceGPerHr,
        'unitSystem': (units ?? current.unitSystem).name,
        if ((weight ?? current.bodyWeightKg) != null)
          'bodyWeightKg': weight ?? current.bodyWeightKg,
        'schema_version': current.schemaVersion,
      };
      final updated = AthleteProfile.fromJson(merged);
      await _storage.saveProfile(updated);
    });
  }
}
