import 'package:flutter/material.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: '친구 · 랭킹',
      description: '친구와 랭킹 기능을 구현할 화면입니다.',
      icon: Icons.people_outline,
    );
  }
}
