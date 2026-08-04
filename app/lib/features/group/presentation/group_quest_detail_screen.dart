import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupQuestDetailScreen extends ConsumerStatefulWidget {
  const GroupQuestDetailScreen({
    required this.groupId,
    required this.questId,
    super.key,
  });
  final int groupId, questId;
  @override
  ConsumerState<GroupQuestDetailScreen> createState() => _State();
}

class _State extends ConsumerState<GroupQuestDetailScreen> {
  GroupQuest? quest;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final q = await ref
          .read(groupRepositoryProvider)
          .quest(widget.groupId, widget.questId);
      if (mounted) setState(() => quest = q);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> cancel() async {
    try {
      await ref
          .read(groupRepositoryProvider)
          .cancelQuest(widget.groupId, widget.questId);
      ref.invalidate(upcomingGroupQuestsProvider(widget.groupId));
      ref.invalidate(pastGroupQuestsProvider(widget.groupId));
      await load();
    } catch (e) {
      if (mounted) showLqError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId)).value;
    final q = quest;
    final modifiable =
        group?.isOwner == true &&
        q != null &&
        q.status == GroupQuestStatus.published &&
        q.scheduledAt.isAfter(DateTime.now()) &&
        group?.archived == false;
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            LqHeader(
              title: '그룹 퀘스트',
              trailing: modifiable
                  ? LqIconButton(
                      icon: Icons.edit,
                      onTap: () => context.push(
                        '/groups/${widget.groupId}/quests/${widget.questId}/edit',
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: q == null
                  ? Center(
                      child: error == null
                          ? const CircularProgressIndicator()
                          : const Text('퀘스트를 불러오지 못했어요'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        LqCard(
                          header: q.title,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.description, style: LqText.body),
                              const SizedBox(height: 12),
                              Text('장소 · ${q.placeName}', style: LqText.label),
                              Text(
                                '일시 · ${q.scheduledAt.year}.${q.scheduledAt.month}.${q.scheduledAt.day} ${q.scheduledAt.hour.toString().padLeft(2, '0')}:${q.scheduledAt.minute.toString().padLeft(2, '0')}',
                                style: LqText.label,
                              ),
                              Text(
                                '작성자 · ${q.creatorNickname}',
                                style: LqText.caption,
                              ),
                              if (q.status == GroupQuestStatus.cancelled)
                                Text(
                                  '취소된 퀘스트',
                                  style: LqText.label.copyWith(
                                    color: LqColors.dangerText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (modifiable) ...[
                          const SizedBox(height: 16),
                          LqButton(
                            label: '퀘스트 취소',
                            shadow: false,
                            borderColor: LqColors.borderMuted,
                            onPressed: cancel,
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
