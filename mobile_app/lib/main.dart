// LOCATION: lib/main.dart
import 'package:flutter/material.dart';
import 'screens/video_dictionary_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sign Language Chatting App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14), // Deep Obsidian Matte Black
        canvasColor: const Color(0xFF161B22),

        // Explicitly defining high-visibility Neon states globally
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF),      // Electric Cyan (Active Borders, Focus highlights)
          secondary: Color(0xFFFF007A),    // Neon Magenta (Main Call to Action Buttons)
          surface: Color(0xFF161B22),      // Dark Steel Card Surface
          onSurface: Color(0xFFF0F3F8),    // Crisp White text on top of cards
          error: Colors.redAccent,
        ),

        // FIXES: Invisible Dictionary/AppBar Icons
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 2,
          centerTitle: true,
          shadowColor: Color(0xFF00F0FF), // Neon glow underneath AppBar
          titleTextStyle: TextStyle(
            color: Color(0xFF00F0FF),      // Title text stands out in Electric Cyan
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF00F0FF), size: 28),
        ),

        // FIXES: Invisible Input Form Fields & Hidden Floating Labels
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161B22),
          labelStyle: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold), // Cyan labels
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIconColor: const Color(0xFF00F0FF),
          suffixIconColor: const Color(0xFF00F0FF),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 2.0),
          ),
        ),

        // FIXES: Invisible Pressed/Unpressed Radio Selection Dots
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00F0FF); // Electric Cyan when checked/pressed
            }
            return Colors.white54; // Clearly visible light grey when unchecked
          }),
        ),

        // FIXES: Invisible Register/Login Buttons text
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF007A), // Hot Magenta
            foregroundColor: Colors.white,            // Bold White Text
            shadowColor: const Color(0xFFFF007A).withAlpha(150),
            elevation: 8,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // FIXES: Missing text buttons (e.g. "Create New Account", "Sign In?")
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00F0FF), // Cyan clickable text link
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ),

        // Global baseline font colors
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF0F3F8)),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}