import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final appState = AppState(storage);
  final settings = SettingsState();
  await Future.wait([appState.load(), settings.load()]);

  runApp(
      MarkRecoderApp(appState: appState, settings: settings, storage: storage));
}

class MarkRecoderApp extends StatelessWidget {
  const MarkRecoderApp({
    super.key,
    required this.appState,
    required this.settings,
    required this.storage,
  });

  final AppState appState;
  final SettingsState settings;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: settings),
        Provider.value(value: storage),
      ],
      child: MaterialApp(
        title: '综测笺',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomePage(),
      ),
    );
  }
}
