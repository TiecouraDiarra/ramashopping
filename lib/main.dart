import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:rama_shopping_app/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialisation Firebase pour le Web
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCnqCks5KT3kMYSWv7EOeh5G2p8_If1BkM",
      authDomain: "rama-shopping-test.firebaseapp.com",
      projectId: "rama-shopping-test",
      storageBucket: "rama-shopping-test.firebasestorage.app",
      messagingSenderId: "629430180730",
      appId: "1:629430180730:web:ce5712fee6f2b23da394c3",
    ),
  );
  runApp(const MyApp());
} 

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rama Shopping',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2E7D32),
          secondary: Color(0xFF81C784),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SplashScreen(), // ← Toujours afficher SplashScreen d'abord
    );
  }
}
