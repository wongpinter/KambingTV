import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KambingTvApp());
}

class KambingTvApp extends StatelessWidget {
  const KambingTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KambingTV',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
