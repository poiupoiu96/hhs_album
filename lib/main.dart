import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';   // 로그인 화면
import 'screens/home_screen.dart';   // 캘린더 화면

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
      title: 'ruVibe',
      theme: ThemeData(primarySwatch: Colors.blue),
      // 🔥 여기서 로그인 상태에 따라 화면을 분기합니다.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const HomeScreen(); // 로그인 완료 -> 캘린더 홈화면
          }
          return const LoginScreen(); // 로그인 전 -> 로그인 화면
        },
      ),
    );
  }
}