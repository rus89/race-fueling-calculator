// ABOUTME: App entry point. Sets up ProviderScope and runs the BonkApp widget.
// ABOUTME: All initialization that needs WidgetsBinding goes here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BonkApp()));
}
