import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../providers/auth_provider.dart';

/// Mock/local auth (Firebase/Auth0 slots in behind [AuthNotifier] later).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  bool _isSignup = false;
  bool _busy = false;

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showAppToast(context, 'Enter a valid email to continue', type: ToastType.error);
      return;
    }
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).signIn(email: email, name: _isSignup ? _name.text : null);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.h32,
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: c.brandGradient,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: const Icon(Icons.movie_creation_rounded, color: Colors.white, size: 32),
              ),
              Gap.h24,
              Text(_isSignup ? 'Create your account' : 'Welcome back', style: context.text.headlineMedium),
              Gap.h8,
              Text(
                _isSignup ? 'Start editing smarter in seconds.' : 'Sign in to continue creating.',
                style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
              Gap.h32,
              if (_isSignup) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                Gap.h12,
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              Gap.h12,
              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              Gap.h24,
              AppButton(label: _isSignup ? 'Create account' : 'Sign in', loading: _busy, onPressed: _submit),
              Gap.h16,
              Row(children: [
                Expanded(child: Divider(color: c.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Text('or', style: TextStyle(color: c.textTertiary)),
                ),
                Expanded(child: Divider(color: c.border)),
              ]),
              Gap.h16,
              AppButton.ghost(label: 'Continue with Google', icon: Icons.g_mobiledata_rounded, expand: true, onPressed: _submit),
              Gap.h12,
              AppButton.ghost(label: 'Continue with Apple', icon: Icons.apple_rounded, expand: true, onPressed: _submit),
              Gap.h24,
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignup = !_isSignup),
                  child: Text.rich(TextSpan(
                    text: _isSignup ? 'Already have an account? ' : "Don't have an account? ",
                    style: TextStyle(color: c.textSecondary),
                    children: [
                      TextSpan(
                        text: _isSignup ? 'Sign in' : 'Sign up',
                        style: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
