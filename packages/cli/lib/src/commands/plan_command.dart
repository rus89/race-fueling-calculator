// ABOUTME: PlanCommand — 'fuel plan create/list/show/delete/generate' and
// ABOUTME: 'fuel plan products add/list' subcommands managing race fueling plans.
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:race_fueling_core/core.dart';

import '../cli/enum_parsers.dart';
import '../cli/errors.dart';
import '../cli/exit_codes.dart';
import '../cli/flag_parsers.dart';
import '../cli/slugify.dart';
import '../cli/tty.dart';
import '../formatting/plain_plan.dart';
import '../products/product_resolver.dart';
import '../prompts/interactive.dart';

class PlanCommand extends Command<void> {
  PlanCommand(
    StorageAdapter storage, {
    IsTtyProbe isTty = defaultIsTty,
    LineReader? readLine,
  }) {
    addSubcommand(
      _PlanCreateCommand(storage, isTty: isTty, readLine: readLine),
    );
    addSubcommand(_PlanListCommand(storage));
    addSubcommand(_PlanShowCommand(storage));
    addSubcommand(
      _PlanDeleteCommand(storage, isTty: isTty, readLine: readLine),
    );
    addSubcommand(_PlanProductsCommand(storage));
    addSubcommand(_PlanGenerateCommand(storage));
  }

  @override
  final String name = 'plan';

  @override
  final String description = 'Create and manage race fueling plans';
}

/// Formats a race duration for display (e.g. "3h30m", "2h", "45m").
String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0 && m > 0) return '${h}h${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

class _PlanCreateCommand extends Command<void> {
  _PlanCreateCommand(
    this._storage, {
    required IsTtyProbe isTty,
    LineReader? readLine,
  })  : _isTty = isTty,
        _readLine = readLine {
    argParser
      ..addOption('name', help: 'Race name (also used to derive the plan id).')
      ..addOption('duration', help: 'Expected duration (e.g. 3h30m or 2:45).')
      ..addOption('distance', help: 'Distance in km (distance mode).')
      ..addOption('target', help: 'Target carbs g/hr.')
      ..addOption(
        'strategy',
        help: 'Distribution strategy (steady, front-load, back-load).',
        defaultsTo: 'steady',
      )
      ..addOption(
        'interval',
        help: 'Interval in minutes (time mode).',
        defaultsTo: '20',
      )
      ..addOption(
        'mode',
        help: 'Timeline mode (time or distance).',
        defaultsTo: 'time',
      )
      ..addOption(
        'interval-km',
        help: 'Interval in km (distance mode).',
      )
      ..addOption('temp', help: 'Temperature in °C.')
      ..addOption('humidity', help: 'Relative humidity %.')
      ..addOption('altitude', help: 'Altitude in meters.')
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite an existing plan with the same derived slug.',
      );
  }

  final StorageAdapter _storage;
  final IsTtyProbe _isTty;
  final LineReader? _readLine;

  @override
  final String name = 'create';

  @override
  final String description = 'Create a new race plan (no products yet)';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('create invoked without parsed arguments');
    }

    final rawName = results['name'] as String?;
    final rawDuration = results['duration'] as String?;
    final rawTarget = results['target'] as String?;
    final rawMode = results['mode'] as String;
    final rawStrategy = results['strategy'] as String;

    final nameMissing = rawName == null || rawName.trim().isEmpty;
    final durationMissing = rawDuration == null;
    final targetMissing = rawTarget == null;

    final missing = <String>[
      if (nameMissing) '--name',
      if (durationMissing) '--duration',
      if (targetMissing) '--target',
    ];

    String? resolvedName = nameMissing ? null : rawName;
    Duration? resolvedDuration;
    double? resolvedTarget;

    if (missing.isNotEmpty) {
      if (!_isTty()) {
        exitWith(
          kExitNoInput,
          'Missing required flag${missing.length == 1 ? '' : 's'}: '
          '${missing.join(', ')}. Pass the flag'
          '${missing.length == 1 ? '' : 's'} or re-run from a terminal.',
        );
        return;
      }
      try {
        if (nameMissing) {
          final prompted = promptString('Race name', readLine: _readLine);
          if (prompted.trim().isEmpty) {
            exitWith(kExitNoInput, 'Race name is required.');
            return;
          }
          resolvedName = prompted;
        }
        if (durationMissing) {
          final prompted = promptDuration(
            'Expected duration (e.g. 3h30m)',
            readLine: _readLine,
          );
          if (prompted == null) {
            exitWith(kExitNoInput, 'Duration is required.');
            return;
          }
          resolvedDuration = prompted;
        }
        if (targetMissing) {
          final prompted = promptDouble(
            'Target carbs g/hr',
            min: 1,
            max: 200,
            readLine: _readLine,
          );
          if (prompted == null) {
            exitWith(kExitNoInput, 'Target carbs/hr is required.');
            return;
          }
          resolvedTarget = prompted;
        }
      } on PromptAbortedException catch (e) {
        exitWith(kExitUsage, e.message);
        return;
      } on NoTerminalException catch (e) {
        exitWith(kExitNoInput, e.message);
        return;
      }
    }

    // Enum parsers must run before numeric guards so typoed modes/strategies
    // surface a UsageException rather than a generic positive-number error.
    final mode = parseModeFlag(rawMode);
    final strategy = parseStrategyFlag(rawStrategy);

    if (resolvedDuration == null) {
      final parsed = parseDuration(rawDuration!);
      if (parsed == null || parsed <= Duration.zero) {
        exitWith(
          kExitUsage,
          '--duration must be positive, got "$rawDuration". '
          'Use e.g. 3h30m or 2:45.',
        );
        return;
      }
      resolvedDuration = parsed;
    }

    if (resolvedTarget == null) {
      final parsed = parseDoubleFlag(results, 'target');
      if (parsed == null || parsed <= 0) {
        exitWith(
          kExitUsage,
          '--target must be positive, got ${parsed ?? rawTarget}.',
        );
        return;
      }
      resolvedTarget = parsed;
    }

    final interval = parseIntFlag(results, 'interval');
    final intervalKm = parseDoubleFlag(results, 'interval-km');
    final distance = parseDoubleFlag(results, 'distance');
    final temperature = parseDoubleFlag(results, 'temp');
    final humidity = parseDoubleFlag(results, 'humidity');
    final altitude = parseDoubleFlag(results, 'altitude');
    final force = results['force'] as bool;

    if (mode == TimelineMode.timeBased) {
      if (interval != null && interval <= 0) {
        exitWith(kExitUsage, '--interval must be positive, got $interval.');
        return;
      }
    } else {
      if (distance == null || distance <= 0) {
        exitWith(
          kExitUsage,
          '--distance must be positive, got ${distance ?? "(missing)"}.',
        );
        return;
      }
      if (intervalKm == null || intervalKm <= 0) {
        exitWith(
          kExitUsage,
          '--interval-km must be positive, got ${intervalKm ?? "(missing)"}.',
        );
        return;
      }
    }

    if (resolvedName == null) {
      throw StateError('resolvedName must be set by this point');
    }
    final slug = slugify(resolvedName);
    if (slug.isEmpty) {
      throw UsageException(
        '--name must contain at least one alphanumeric character, got '
            '"$resolvedName".',
        'Pass a name like "My Big Race".',
      );
    }

    final config = RaceConfig(
      name: resolvedName,
      duration: resolvedDuration,
      distanceKm: distance,
      timelineMode: mode,
      intervalMinutes: mode == TimelineMode.timeBased ? interval : null,
      intervalKm: mode == TimelineMode.distanceBased ? intervalKm : null,
      targetCarbsGPerHr: resolvedTarget,
      strategy: strategy,
      selectedProducts: const [],
      temperature: temperature,
      humidity: humidity,
      altitudeM: altitude,
    );

    await withFriendlyErrors(() async {
      final existingPlans = await _storage.listPlans();
      if (existingPlans.contains(slug) && !force) {
        exitWith(
          kExitUsage,
          'Plan "$slug" already exists. Use --force to overwrite or choose '
          'a different --name.',
        );
        return;
      }

      await _storage.savePlan(slug, config);
      stdout.writeln(
        'Plan "$slug" created. Add products with '
        "'fuel plan products add <product> --plan $slug --quantity N' "
        "then run 'fuel plan generate --plan $slug'.",
      );
    });
  }
}

class _PlanListCommand extends Command<void> {
  _PlanListCommand(this._storage);

  final StorageAdapter _storage;

  @override
  final String name = 'list';

  @override
  final String description = 'List saved plans';

  @override
  Future<void> run() async {
    await withFriendlyErrors(() async {
      final plans = await _storage.listPlans();
      if (plans.isEmpty) {
        stderr.writeln('No saved plans.');
        return;
      }
      final sorted = [...plans]..sort();
      for (final name in sorted) {
        stdout.writeln(name);
      }
    });
  }
}

class _PlanShowCommand extends Command<void> {
  _PlanShowCommand(this._storage);

  final StorageAdapter _storage;

  @override
  final String name = 'show';

  @override
  final String description = 'Show details of a saved plan';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('show invoked without parsed arguments');
    }
    final planName = results.rest.isEmpty ? null : results.rest.first;
    if (planName == null) {
      throw UsageException(
        'Missing plan name.',
        'Usage: fuel plan show <plan-name>',
      );
    }

    await withFriendlyErrors(() async {
      final config = await _storage.loadPlan(planName);
      if (config == null) {
        exitWith(kExitUsage, 'Plan not found: $planName');
        return;
      }
      stdout.writeln('Name: ${config.name}');
      stdout.writeln('Duration: ${_formatDuration(config.duration)}');
      if (config.distanceKm != null) {
        stdout.writeln('Distance: ${config.distanceKm}km');
      }
      stdout.writeln('Target: ${config.targetCarbsGPerHr}g/hr');
      stdout.writeln('Strategy: ${config.strategy.name}');
      stdout.writeln('Mode: ${config.timelineMode.name}');
      if (config.intervalMinutes != null) {
        stdout.writeln('Interval: ${config.intervalMinutes}min');
      }
      if (config.intervalKm != null) {
        stdout.writeln('Interval: ${config.intervalKm}km');
      }
      if (config.temperature != null) {
        stdout.writeln('Temperature: ${config.temperature}°C');
      }
      if (config.humidity != null) {
        stdout.writeln('Humidity: ${config.humidity}%');
      }
      if (config.altitudeM != null) {
        stdout.writeln('Altitude: ${config.altitudeM}m');
      }
      stdout.writeln('Products: ${config.selectedProducts.length}');
    });
  }
}

class _PlanDeleteCommand extends Command<void> {
  _PlanDeleteCommand(
    this._storage, {
    required IsTtyProbe isTty,
    LineReader? readLine,
  })  : _isTty = isTty,
        _readLine = readLine {
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Skip the confirmation prompt.',
    );
  }

  final StorageAdapter _storage;
  final IsTtyProbe _isTty;
  final LineReader? _readLine;

  @override
  final String name = 'delete';

  @override
  final String description = 'Delete a saved plan';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('delete invoked without parsed arguments');
    }
    final planName = results.rest.isEmpty ? null : results.rest.first;
    if (planName == null) {
      throw UsageException(
        'Missing plan name.',
        'Usage: fuel plan delete <plan-name> [--yes]',
      );
    }
    final yes = results['yes'] as bool;

    await withFriendlyErrors(() async {
      final existing = await _storage.listPlans();
      if (!existing.contains(planName)) {
        exitWith(kExitUsage, 'Plan not found: $planName');
        return;
      }

      if (!yes) {
        if (!_isTty()) {
          exitWith(
            kExitNoInput,
            'Interactive input requires a TTY. Pass --yes to skip the '
            'confirmation prompt.',
          );
          return;
        }
        try {
          final confirmed = promptBool(
            'Delete plan "$planName"?',
            defaultValue: false,
            readLine: _readLine,
          );
          if (!confirmed) {
            stdout.writeln('Delete cancelled.');
            return;
          }
        } on NoTerminalException {
          exitWith(
            kExitNoInput,
            'No input available. Pass --yes to skip the confirmation prompt.',
          );
          return;
        } on PromptAbortedException catch (e) {
          exitWith(kExitUsage, e.message);
          return;
        }
      }

      await _storage.deletePlan(planName);
      stdout.writeln('Deleted plan "$planName".');
    });
  }
}

class _PlanProductsCommand extends Command<void> {
  _PlanProductsCommand(StorageAdapter storage) {
    addSubcommand(_PlanProductsAddCommand(storage));
    addSubcommand(_PlanProductsListCommand(storage));
  }

  @override
  final String name = 'products';

  @override
  final String description = 'Manage products selected for a plan';
}

class _PlanProductsAddCommand extends Command<void> {
  _PlanProductsAddCommand(this._storage) {
    argParser
      ..addOption('plan', help: 'Plan slug (as shown by `fuel plan list`).')
      ..addOption('quantity', abbr: 'q', help: 'Servings carried.');
  }

  final StorageAdapter _storage;

  @override
  final String name = 'add';

  @override
  final String description = 'Add a product to a plan';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('add invoked without parsed arguments');
    }
    final planName = results['plan'] as String?;
    if (planName == null || planName.trim().isEmpty) {
      throw UsageException(
        'Missing --plan.',
        'Pass --plan <plan-slug>.',
      );
    }
    final query = results.rest.join(' ').trim();
    if (query.isEmpty) {
      throw UsageException(
        'Missing product query.',
        'Usage: fuel plan products add <product> --plan <slug> '
            '--quantity N',
      );
    }
    final rawQty = results['quantity'] as String?;
    if (rawQty == null) {
      throw UsageException(
        'Missing --quantity.',
        'Pass --quantity <integer>.',
      );
    }
    final quantity = int.tryParse(rawQty);
    if (quantity == null) {
      throw UsageException(
        'Expected an integer for --quantity, got "$rawQty"',
        'Pass --quantity <integer>.',
      );
    }
    if (quantity <= 0) {
      exitWith(kExitUsage, '--quantity must be positive, got $quantity.');
      return;
    }

    await withFriendlyErrors(() async {
      final config = await _storage.loadPlan(planName);
      if (config == null) {
        exitWith(kExitUsage, 'Plan not found: $planName');
        return;
      }

      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final match = resolveProduct(all, query);
      switch (match) {
        case ProductMatchNone():
          exitWith(kExitUsage, 'No product matched: $query');
          return;
        case ProductMatchMultiple(:final candidates):
          writeCandidates(stderr, candidates);
          exitCode = kExitUsage;
          return;
        case ProductMatchSingle(:final product):
          final existingIndex = config.selectedProducts
              .indexWhere((sel) => sel.productId == product.id);
          if (existingIndex >= 0) {
            final existing = config.selectedProducts[existingIndex];
            final mergedQuantity = existing.quantity + quantity;
            final updatedSelections = [...config.selectedProducts];
            updatedSelections[existingIndex] = ProductSelection(
              productId: existing.productId,
              quantity: mergedQuantity,
              isAidStationOnly: existing.isAidStationOnly,
            );
            final updated =
                config.copyWith(selectedProducts: updatedSelections);
            await _storage.savePlan(planName, updated);
            stdout.writeln(
              'Updated "${product.name}" in plan "$planName": '
              'quantity now $mergedQuantity.',
            );
          } else {
            final updatedSelections = [
              ...config.selectedProducts,
              ProductSelection(
                productId: product.id,
                quantity: quantity,
              ),
            ];
            final updated =
                config.copyWith(selectedProducts: updatedSelections);
            await _storage.savePlan(planName, updated);
            stdout.writeln(
              'Added ${product.name} x$quantity to plan "$planName".',
            );
          }
      }
    });
  }
}

class _PlanProductsListCommand extends Command<void> {
  _PlanProductsListCommand(this._storage) {
    argParser.addOption('plan',
        help: 'Plan slug (as shown by `fuel plan list`).');
  }

  final StorageAdapter _storage;

  @override
  final String name = 'list';

  @override
  final String description = 'List products selected for a plan';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('list invoked without parsed arguments');
    }
    final planName = results['plan'] as String?;
    if (planName == null || planName.trim().isEmpty) {
      throw UsageException(
        'Missing --plan.',
        'Pass --plan <plan-slug>.',
      );
    }

    await withFriendlyErrors(() async {
      final config = await _storage.loadPlan(planName);
      if (config == null) {
        exitWith(kExitUsage, 'Plan not found: $planName');
        return;
      }
      if (config.selectedProducts.isEmpty) {
        stderr.writeln('No products in plan "$planName".');
        return;
      }

      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final byId = {for (final p in all) p.id: p};

      for (final selection in config.selectedProducts) {
        final product = byId[selection.productId];
        final name = product?.name ?? selection.productId;
        final tag = selection.isAidStationOnly ? ' [aid station]' : '';
        stdout.writeln('  $name x${selection.quantity}$tag');
      }
    });
  }
}

class _PlanGenerateCommand extends Command<void> {
  _PlanGenerateCommand(this._storage) {
    argParser.addOption('plan', help: 'Plan slug.');
  }

  final StorageAdapter _storage;

  @override
  final String name = 'generate';

  @override
  final String description = 'Generate the fueling plan timeline';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      throw StateError('generate invoked without parsed arguments');
    }
    final planName = results['plan'] as String?;
    if (planName == null || planName.trim().isEmpty) {
      throw UsageException(
        'Missing --plan.',
        'Pass --plan <plan-slug>.',
      );
    }

    await withFriendlyErrors(() async {
      final config = await _storage.loadPlan(planName);
      if (config == null) {
        exitWith(kExitUsage, 'Plan not found: $planName');
        return;
      }
      if (config.selectedProducts.isEmpty) {
        exitWith(
          kExitUsage,
          'Plan "$planName" has no products. Add some with: '
          'fuel plan products add <product> --plan $planName --quantity N.',
        );
        return;
      }
      final profile = await _storage.loadProfile();
      if (profile == null) {
        exitWith(
          kExitData,
          "No profile found. Run 'fuel profile setup' first.",
        );
        return;
      }

      final userProducts = await _storage.loadUserProducts();
      final all = mergeProducts(builtInProducts, userProducts);
      final byId = {for (final p in all) p.id: p};

      // Surface a caffeine-safety advisory up-front when the plan references
      // any caffeinated product and we don't have a body weight to check
      // mg/kg thresholds against.
      if (profile.bodyWeightKg == null) {
        final hasCaffeine = config.selectedProducts.any((sel) {
          final product = byId[sel.productId];
          return product != null && product.caffeineMg > 0;
        });
        if (hasCaffeine) {
          stderr.writeln(
            'Warning: caffeine safety checks are weakened without '
            "bodyWeightKg. Run 'fuel profile set --weight <kg>' for full "
            'coverage.',
          );
        }
      }

      final plan = generatePlan(config, profile, all);
      stdout.write(formatPlanText(plan));
    });
  }
}
