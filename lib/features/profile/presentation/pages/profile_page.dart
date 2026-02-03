import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Выйти (заглушка)'),
        ),
      ),
    );
  }
}
// to do