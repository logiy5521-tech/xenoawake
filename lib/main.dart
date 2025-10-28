import 'package:flutter/material.dart';
import 'resource_calculator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _locale = 'ja';

  void _changeLocale(String newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '異獣ペット覚醒計算ツール',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: ResourceCalculatorScreen(locale: _locale, onLocaleChange: _changeLocale),
    );
  }
}
