import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      await ref.read(authControllerProvider.notifier).loginWithGoogle();
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: '다시 만난 모험가님!',
      subtitle: '오늘의 작은 퀘스트를 시작해 볼까요?',
      child: LqCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _emailController,
                label: '이메일',
                hint: 'quest@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordController,
                label: '비밀번호',
                hint: '8자 이상 입력',
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: validatePassword,
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              LqButton(label: '로그인', busy: _busy, onPressed: _login),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider(color: LqColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('또는', style: LqText.caption),
                  ),
                  const Expanded(child: Divider(color: LqColors.divider)),
                ],
              ),
              const SizedBox(height: 14),
              LqButton(
                label: 'Google로 계속하기',
                busy: _googleBusy,
                background: Colors.white,
                foreground: LqColors.textPrimary,
                icon: const Text(
                  'G',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4285F4),
                  ),
                ),
                onPressed: _googleLogin,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('아직 계정이 없나요?', style: LqText.bodySm),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: Text(
                      '회원가입',
                      style: LqText.bodySm.copyWith(
                        color: LqColors.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
