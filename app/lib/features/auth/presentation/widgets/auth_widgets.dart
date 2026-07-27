import 'package:flutter/material.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LqSpacing.screen,
            22,
            LqSpacing.screen,
            32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - 86,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: LqColors.ink,
                    ),
                  )
                else
                  const SizedBox(height: 24),
                const _QuestMark(),
                const SizedBox(height: 22),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: LqText.bigTitle,
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: LqText.bodySm.copyWith(color: LqColors.textSecondary),
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestMark extends StatelessWidget {
  const _QuestMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.025,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: LqColors.primary,
            border: Border.all(color: LqColors.ink, width: LqShape.borderWidth),
            borderRadius: LqShape.cardRadius,
            boxShadow: LqShape.buttonShadow,
          ),
          child: Text(
            'LIFE QUEST',
            style: LqText.sectionTitle.copyWith(
              color: LqColors.onDark,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: LqText.label.copyWith(
            color: LqColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscured,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          style: LqText.body,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: LqText.body.copyWith(color: LqColors.textMuted),
            filled: true,
            fillColor: LqColors.surfaceRaised,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: LqColors.textMuted,
                    ),
                  )
                : null,
            enabledBorder: const OutlineInputBorder(
              borderRadius: LqShape.rowRadius,
              borderSide: BorderSide(
                color: LqColors.borderMuted,
                width: LqShape.borderWidth,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: LqShape.rowRadius,
              borderSide: BorderSide(
                color: LqColors.primary,
                width: LqShape.borderWidth,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: LqShape.rowRadius,
              borderSide: BorderSide(
                color: LqColors.dangerText,
                width: LqShape.borderWidth,
              ),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: LqShape.rowRadius,
              borderSide: BorderSide(
                color: LqColors.dangerText,
                width: LqShape.borderWidth,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return '이메일을 입력해 주세요.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return '올바른 이메일 형식이 아니에요.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
  if (value.length < 8) return '비밀번호는 8자 이상이어야 해요.';
  return null;
}
