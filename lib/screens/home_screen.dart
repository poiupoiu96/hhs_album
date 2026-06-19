import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('우리가족 앨범 👨‍👩‍👦')),
      body: const Center(
        child: Text('여기에 사진들이 올라올 예정입니다!👶'),
      ),
    );
  }
}