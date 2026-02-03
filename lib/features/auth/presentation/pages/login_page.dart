import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/profile'),
          child: const Text('Войти (заглушка)'),
        ),
      ),
    );
  }
}
// to do