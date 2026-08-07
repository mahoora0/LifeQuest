import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/recommendation/application/quest_recommendation_provider.dart';
import 'package:life_quest/shared/error/lq_error_messages.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';

class RecommendationTypeScreen extends ConsumerWidget {
  const RecommendationTypeScreen({this.weekly = false, super.key});

  /// 주간 퀘스트 슬롯을 채우러 들어왔는가. 아래 두 경로로 그대로 넘긴다.
  final bool weekly;

  String _path(String type) =>
      '/quest-recommendations/$type${weekly ? '?weekly=true' : ''}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 주간 모드에서만 슬롯 상태를 묻는다. 이미 받았으면 여기서 막아야 사용자가
    // 추천을 돌려 LLM 비용을 쓰고 마지막 선택에서야 거절당하는 일이 없다.
    final status = weekly
        ? ref.watch(weeklyAiQuestStatusProvider)
        : null;
    final blockedReason = status?.value != null && !status!.value!.available
        ? status.value!.reason
        : null;

    return Scaffold(
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
                      child: Text(
                        blockedReason != null
                            ? lqErrorMessageForCode(blockedReason)
                            : '고른 퀘스트 하나가 이번 주 주간 퀘스트로 들어가요. 주에 한 번만 받을 수 있어요.',
                      ),
                    ),
                  ),
                LqCard(
                  // 자리가 없으면 진입 자체를 막는다 — 들어가 봐야 추천만 태우고 거절된다.
                  onTap: blockedReason != null
                      ? null
                      : () => context.push(_path('place')),
                  child: const ListTile(
                    leading: Icon(Icons.place_outlined),
                    title: Text('장소 추천'),
                    subtitle: Text('지금 갈 지역·시간·예산에 맞는 경험 3개'),
                  ),
                ),
                const SizedBox(height: 12),
                LqCard(
                  onTap: blockedReason != null
                      ? null
                      : () => context.push(_path('travel')),
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
}
