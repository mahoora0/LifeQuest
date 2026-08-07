import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
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
  bool busy = false;
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
      // 그룹 상세는 최근 그룹 퀘스트 3개를 함께 내려주므로 취소 후 낡은 채로 남는다.
      _invalidateQuestLists();
      await load();
    } catch (e) {
      if (mounted) showLqError(context, e);
    }
  }

  Future<void> apply() => _run(
    () => ref
        .read(groupRepositoryProvider)
        .applyToQuest(widget.groupId, widget.questId),
    '참여 신청을 완료했어요',
  );

  Future<void> withdraw() => _run(
    () => ref
        .read(groupRepositoryProvider)
        .withdrawFromQuest(widget.groupId, widget.questId),
    '참여 신청을 취소했어요',
  );

  Future<void> complete() => _run(
    () => ref
        .read(groupRepositoryProvider)
        .completeGroupQuest(widget.groupId, widget.questId),
    '참여자 모두에게 EXP를 지급했어요',
    refreshLevel: true,
  );

  Future<void> _run(
    Future<GroupQuest> Function() action,
    String message, {
    bool refreshLevel = false,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => quest = updated);
      _invalidateQuestLists();
      if (refreshLevel) ref.invalidate(levelStatusProvider);
      showLqSnack(context, message);
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _invalidateQuestLists() {
    ref.invalidate(upcomingGroupQuestsProvider(widget.groupId));
    ref.invalidate(pastGroupQuestsProvider(widget.groupId));
    ref.invalidate(groupDetailProvider(widget.groupId));
    ref.invalidate(myCoopGroupQuestsProvider);
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
    final participationOpen =
        q != null &&
        q.status == GroupQuestStatus.published &&
        q.scheduledAt.isAfter(DateTime.now()) &&
        group?.isActiveMember == true &&
        group?.archived == false;
    final completable =
        q != null &&
        q.status == GroupQuestStatus.published &&
        !q.scheduledAt.isAfter(DateTime.now()) &&
        group?.isOwner == true &&
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
                              const SizedBox(height: 8),
                              Text(
                                '참여 ${q.participantCount}명 · 공동 완료 시 ${q.expReward} EXP',
                                style: LqText.label,
                              ),
                              if (q.isParticipating)
                                Text('내 상태 · 참여 신청 완료', style: LqText.label),
                              if (q.rewarded)
                                Text('내 상태 · EXP 지급 완료', style: LqText.label),
                              if (q.participants.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('참여자', style: LqText.cardTitle),
                                for (final participant in q.participants)
                                  Text(
                                    '· ${participant.nickname}${participant.status == GroupQuestParticipationStatus.rewarded ? ' · 지급 완료' : ''}',
                                    style: LqText.caption,
                                  ),
                              ],
                              if (q.status == GroupQuestStatus.completed)
                                Text(
                                  '공동 완료된 퀘스트',
                                  style: LqText.label.copyWith(
                                    color: LqColors.successText,
                                  ),
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
                        if (participationOpen) ...[
                          const SizedBox(height: 16),
                          LqButton(
                            label: q.isParticipating ? '참여 신청 취소' : '참여 신청',
                            busy: busy,
                            shadow: !q.isParticipating,
                            borderColor: q.isParticipating
                                ? LqColors.borderMuted
                                : LqColors.ink,
                            onPressed: q.isParticipating ? withdraw : apply,
                          ),
                        ],
                        if (completable) ...[
                          const SizedBox(height: 16),
                          LqButton(
                            label: '그룹 공동 완료 · ${q.expReward} EXP 지급',
                            busy: busy,
                            onPressed: complete,
                          ),
                        ],
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
