import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

class RecommendationTypeScreen extends StatelessWidget {
  const RecommendationTypeScreen({this.weekly = false, super.key});

  /// 주간 퀘스트 슬롯을 채우러 들어왔는가. 아래 두 경로로 그대로 넘긴다.
  final bool weekly;

  String _path(String type) =>
      '/quest-recommendations/$type${weekly ? '?weekly=true' : ''}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LqColors.surfacePanel,
    body: SafeArea(
      child: Column(
        children: [
          LqHeader(title: weekly ? '주간 퀘스트 받기' : 'AI 퀘스트 추천'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (weekly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: LqColors.warnBg,
                        borderRadius: LqShape.rowRadius,
                      ),
                      child: const Text(
                        '고른 퀘스트 하나가 이번 주 주간 퀘스트로 들어가요. 주에 한 번만 받을 수 있어요.',
                      ),
                    ),
                  ),
                LqCard(
                  onTap: () => context.push(_path('place')),
                  child: const ListTile(
                    leading: Icon(Icons.place_outlined),
                    title: Text('장소 추천'),
                    subtitle: Text('지금 갈 지역·시간·예산에 맞는 경험 3개'),
                  ),
                ),
                const SizedBox(height: 12),
                LqCard(
                  onTap: () => context.push(_path('travel')),
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
