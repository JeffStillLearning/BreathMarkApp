import 'package:flutter/material.dart';
import 'constants.dart';
import 'screens/home_screen.dart';
import 'screens/checkin_screen.dart';
import 'screens/tremor_screen.dart';
import 'screens/breathing_screen.dart';
import 'screens/history_screen.dart';

void main() {
  runApp(const BreathMarkApp());
}

class BreathMarkApp extends StatelessWidget {
  const BreathMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreathMark',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kGreenMed),
        useMaterial3: true,
        fontFamily: 'PlusJakartaSans',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/checkin': (context) => const CheckinScreen(),
        '/tremor': (context) => const TremorScreen(),
        '/breathing': (context) => const BreathingScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
