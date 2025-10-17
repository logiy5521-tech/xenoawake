import 'package:flutter/material.dart';
import 'calculator_screen.dart';

void main() {
  runApp(const XenoPetsCalculatorApp());
}

class XenoPetsCalculatorApp extends StatelessWidget {
  const XenoPetsCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XenoPets覚醒計算ツール',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const CalculatorScreen(),
    );
  }
}
