import 'package:flutter/material.dart';

import '../shared/localization/example_strings.dart';
import 'app_shell.dart';

export 'app_shell.dart';
export '../features/player/presentation/player_example_page.dart';

/// Root widget for the example application.
///
/// Keeping the `MaterialApp` here makes the executable entry point small and
/// gives tests a stable root widget to pump.
class PlayerM3u8ExampleApp extends StatelessWidget {
  const PlayerM3u8ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: const ExampleStrings(ExampleLanguage.zh).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const DemoShell(),
    );
  }
}

/// @deprecated Use [PlayerM3u8ExampleApp].
typedef PlayerM3u8ExampleAppBase = PlayerM3u8ExampleApp;

/// @deprecated Use [DemoShell].
typedef DemoShellBase = DemoShell;
