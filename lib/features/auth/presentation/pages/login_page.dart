import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../../../../core/utils/validators.dart';
import '../auth_session_reset.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final loginValue = _loginController.text.trim();
    final normalizedLogin = loginValue.contains('@')
        ? loginValue
        : Validators.normalizePhone(loginValue);
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(normalizedLogin, _passwordController.text);

    if (!mounted || !success) {
      return;
    }

    resetUserScopedProviders(ref);
    context.go('/communities');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                const AppPageHeader(
                  title: 'Добро пожаловать',
                  subtitle:
                      'Помогайте соседям, получайте помощь и оставайтесь на связи со своим ближайшим окружением.',
                ),
                const SizedBox(height: 20),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: 'Вход в аккаунт',
                        subtitle:
                            'Используйте телефон или электронную почту, чтобы войти в аккаунт.',
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _loginController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Телефон или e-mail',
                        ),
                        validator: (value) {
                          final input = (value ?? '').trim();
                          if (input.isEmpty) {
                            return 'Введите номер телефона или адрес электронной почты';
                          }
                          if (input.contains('@')) {
                            return Validators.email(input);
                          }
                          return Validators.phone(
                            Validators.normalizePhone(input),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Введите пароль';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      if (authState.error != null) ...[
                        Text(
                          authState.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: authState.loading ? null : _submit,
                        child: authState.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Войти'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: authState.loading
                            ? null
                            : () => context.go('/register'),
                        child: const Text('Создать аккаунт'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Будьте уважительны ко всем пользователям, ведь основа этого сервиса - поддержка и взаимопощь.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
