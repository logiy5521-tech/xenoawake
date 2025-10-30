import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locale = prefs.getString('locale') ?? 'ja';
    });
  }

  void _changeLocale(String newLocale) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('locale', newLocale);
      setState(() {
        _locale = newLocale;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resource Calculator',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: ResourceCalculatorScreen(locale: _locale, onLocaleChange: _changeLocale),
    );
  }
}
