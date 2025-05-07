import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:book_mate/pages/welcomePage.dart';
import 'package:book_mate/pages/mainPage.dart';
import 'package:book_mate/pages/marketPage.dart';
import 'package:book_mate/pages/myBooksPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const WelcomePage(),
      routes: {
        '/mainPage': (context) => const MainPage(),
        '/marketPage': (context) => const MarketPage(),
        '/myBooksPage': (context) => const MyBooksPage(),
        '/welcomePage': (context) => const WelcomePage(),
      },
    );
  }
}
