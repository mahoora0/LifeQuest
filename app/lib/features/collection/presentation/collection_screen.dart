import 'package:flutter/material.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: '도감 · 업적',
      description: 'LifeDex와 업적 기능을 구현할 화면입니다.',
      icon: Icons.auto_stories_outlined,
    );
  }
}
