// ABOUTME: Resolution smoke for the cli_api / cli_runner public surfaces.
// ABOUTME: Catches accidental rename or removal of an exported symbol at CI time.
import 'package:race_fueling_cli/cli_api.dart' as api;
import 'package:race_fueling_cli/cli_runner.dart' as runner;
import 'package:test/test.dart';

void main() {
  test('cli_api exports key embedder symbols', () {
    expect(api.FileStorageAdapter, isNotNull);
    expect(api.formatPlanTable, isNotNull);
    expect(api.formatSummaryBlock, isNotNull);
    expect(api.resolveColorMode, isNotNull);
    expect(api.parseDuration, isNotNull);
    expect(api.kExitSuccess, 0);
    expect(api.kExitUsage, 64);
    expect(api.kExitData, 65);
    expect(api.withFriendlyErrors, isNotNull);
  });

  test('cli_runner re-exports cli_api and adds command classes', () {
    expect(runner.FileStorageAdapter, isNotNull); // re-export
    expect(runner.formatPlanTable, isNotNull); // re-export
    expect(runner.ProfileCommand, isNotNull);
    expect(runner.ProductsCommand, isNotNull);
    expect(runner.PlanCommand, isNotNull);
  });
}
