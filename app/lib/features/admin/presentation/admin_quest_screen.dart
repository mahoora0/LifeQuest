import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/admin/application/admin_quest_providers.dart';
import 'package:life_quest/features/admin/data/admin_quest.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class AdminQuestScreen extends ConsumerWidget {
  const AdminQuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(adminQuestsProvider);
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/quests/new'),
        backgroundColor: LqColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('퀘스트 등록'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '관리자 퀘스트 관리'),
            Expanded(
              child: LqAsyncView<List<AdminQuest>>(
                value: quests,
                onRetry: () => ref.invalidate(adminQuestsProvider),
                isEmpty: (items) => items.isEmpty,
                emptyMessage: '등록된 퀘스트가 없어요',
                data: (items) => RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminQuestsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _QuestCard(items[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard(this.quest);

  final AdminQuest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LqCard(
      background: LqColors.surfaceCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(quest.title, style: LqText.cardTitle)),
              Text(quest.active ? '활성' : '비활성', style: LqText.caption),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${quest.grade} · ${quest.cadence} · ${quest.completionType} · EXP ${quest.expReward}',
            style: LqText.caption,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.push(
                  '/admin/quests/${quest.id}/edit',
                  extra: quest,
                ),
                child: const Text('수정'),
              ),
              if (quest.active)
                TextButton(
                  onPressed: () => _deactivate(context, ref),
                  child: const Text('삭제'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀘스트를 삭제할까요?'),
        content: const Text('기존 기록은 보존되고 신규 배정에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(adminQuestsProvider.notifier).deactivate(quest.id);
      if (context.mounted) showLqSnack(context, '퀘스트를 비활성화했어요');
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }
}
