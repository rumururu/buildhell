import 'package:flutter/material.dart';

import 'game/game_state.dart';
import 'game/save_service.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final save = await SaveService.create();
  final state = GameState();
  save.loadInto(state);
  runApp(BuildHellApp(state: state, save: save));
}

class BuildHellApp extends StatelessWidget {
  const BuildHellApp({super.key, required this.state, this.save});

  final GameState state;
  final SaveService? save;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지옥키우기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF120606),
        useMaterial3: true,
      ),
      home: HomePage(state: state, save: save),
    );
  }
}
