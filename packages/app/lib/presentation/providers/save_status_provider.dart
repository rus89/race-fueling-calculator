// ABOUTME: Tracks the most recent save attempt's outcome for UI surfacing.
// ABOUTME: Idle / inFlight / failed; F1 renders a banner when state == failed.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lifecycle of the auto-save chain. `failed` is sticky in the sense that it
/// is only cleared by a subsequent successful save (matching the user mental
/// model: "are saves working *right now*?"). The Notifier moves through
/// idle → inFlight → idle on success, idle → inFlight → failed on failure.
enum SaveStatus { idle, inFlight, failed }

class SaveStatusController extends Notifier<SaveStatus> {
  @override
  SaveStatus build() => SaveStatus.idle;

  void markInFlight() => state = SaveStatus.inFlight;
  void markSuccess() => state = SaveStatus.idle;
  void markFailed() => state = SaveStatus.failed;
}

final saveStatusProvider = NotifierProvider<SaveStatusController, SaveStatus>(
  SaveStatusController.new,
);
