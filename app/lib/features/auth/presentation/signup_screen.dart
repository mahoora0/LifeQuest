import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/auth/application/auth_controller.dart';
import 'package:life_quest/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signup(
            email: _emailController.text,
            password: _passwordController.text,
            nickname: _nicknameController.text,
          );
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: '새 모험가 등록',
      subtitle: '당신만의 이름으로 첫 퀘스트를 준비해요.',
      child: LqCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Form(
          key: _formKey,
          child: Column(
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
                controller: _nicknameController,
                label: '닉네임',
                hint: '2~20자, 한글·영문·숫자',
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final nickname = value?.trim() ?? '';
                  if (nickname.length < 2 || nickname.length > 20) {
                    return '닉네임은 2~20자로 입력해 주세요.';
                  }
                  if (!RegExp(r'^[가-힣a-zA-Z0-9_]+$').hasMatch(nickname)) {
                    return '한글, 영문, 숫자, 밑줄만 사용할 수 있어요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordController,
                label: '비밀번호',
                hint: '8자 이상 입력',
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: validatePassword,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordConfirmController,
                label: '비밀번호 확인',
                hint: '한 번 더 입력',
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    value != _passwordController.text ? '비밀번호가 서로 달라요.' : null,
                onFieldSubmitted: (_) => _signup(),
              ),
              const SizedBox(height: 22),
              LqButton(label: '가입하고 시작하기', busy: _busy, onPressed: _signup),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(
                  '이미 계정이 있어요',
                  style: LqText.bodySm.copyWith(
                    color: LqColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
