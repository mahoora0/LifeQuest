import 'package:flutter/material.dart';
import 'package:life_quest/shared/presentation/feature_placeholder_screen.dart';

class MapPlaceholderScreen extends StatelessWidget {
  const MapPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: '지도',
      description: '지도 SDK 선정 후 이 화면에 연결합니다.\n현재는 어떤 지도 제공자에도 의존하지 않습니다.',
      icon: Icons.map_outlined,
    );
  }
}
