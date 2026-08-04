import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

class RecommendationTypeScreen extends StatelessWidget {
  const RecommendationTypeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LqColors.surfacePanel,
    body: SafeArea(
      child: Column(
        children: [
          const LqHeader(title: 'AI 퀘스트 추천'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                LqCard(
                  onTap: () => context.push('/quest-recommendations/place'),
                  child: const ListTile(
                    leading: Icon(Icons.place_outlined),
                    title: Text('장소 추천'),
                    subtitle: Text('지금 갈 지역·시간·예산에 맞는 경험 3개'),
                  ),
                ),
                const SizedBox(height: 12),
                LqCard(
                  onTap: () => context.push('/quest-recommendations/travel'),
                  child: const ListTile(
                    leading: Icon(Icons.luggage_outlined),
                    title: Text('여행 추천'),
                    subtitle: Text('여행지·기간·예산에 맞는 경험 3개'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
