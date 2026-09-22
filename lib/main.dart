import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CatDogApp());
}

class CatDogApp extends StatelessWidget {
  const CatDogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cat vs Dog AI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}