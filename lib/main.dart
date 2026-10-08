import 'package:flutter/material.dart';

import 'game/game_state.dart';
import 'game/save_service.dart';
import 'services/ad_service.dart';
import 'services/sound_service.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final save = await SaveService.create();
  final state = GameState();
  save.loadInto(state);
  final feedback = AudioFeedback()..preload();
  runApp(
    BuildHellApp(
      state: state,
      save: save,
      feedback: feedback,
      ads: AdService.create(),
    ),
  );
}

class BuildHellApp extends StatelessWidget {
  const BuildHellApp({
    super.key,
    required this.state,
    this.save,
    this.feedback = const SilentFeedback(),
    this.ads,
  });

  final GameState state;
  final SaveService? save;
  final FeedbackService feedback;
  final AdService? ads;

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
      home: HomePage(
        state: state,
        save: save,
        feedback: feedback,
        ads: ads ?? NoAdService(),
      ),
    );
  }
}
