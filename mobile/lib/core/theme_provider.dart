import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// App-wide theme mode, driven by the Settings screen (light / dark / system).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
