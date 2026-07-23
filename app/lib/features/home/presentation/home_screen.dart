import 'package:flutter/material.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: '오늘의 퀘스트',
      description: '오늘 배정된 퀘스트 기능을 구현할 화면입니다.',
      icon: Icons.flag_outlined,
    );
  }
}
