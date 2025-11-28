import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MermaidEditorApp());
}

class MermaidEditorApp extends StatelessWidget {
  const MermaidEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mermaid Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFE771B),
          brightness: Brightness.light,
        ).copyWith(
          secondary: const Color(0xFFFEB565),
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFE771B),
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFFEB565),
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const HomeScreen(),
    );
  }
}
