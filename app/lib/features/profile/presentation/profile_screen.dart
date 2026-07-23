import 'package:flutter/material.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: '마이페이지',
      description: '프로필, 레벨, 칭호 기능을 구현할 화면입니다.',
      icon: Icons.person_outline,
    );
  }
}
