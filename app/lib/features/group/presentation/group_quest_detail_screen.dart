import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/user/application/user_providers.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/presentation/date_labels.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀘스트를 취소할까요?'),
        content: const Text('취소하면 다시 진행할 수 없지만 기록은 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('돌아가기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('퀘스트 취소'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  Future<void> deletePermanently() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀘스트를 영구 삭제할까요?'),
        content: const Text('퀘스트와 모든 참여 기록이 삭제되며 복구할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .deleteQuestPermanently(widget.groupId, widget.questId);
      _invalidateQuestLists();
      if (mounted) context.go('/groups/${widget.groupId}');
    } catch (e) {
      if (mounted) showLqError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
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
    // 완료는 참여자 개개인이 아니라 그룹장이 한 번 눌러 참여자 전원에게 EXP를
    // 지급하는 방식이다. 조건이 어긋나면 버튼 자리가 그냥 비어 "완료 버튼이 없다"로
    // 읽히므로, 왜 못 누르는지를 같은 자리에 남긴다.
    final String? completionHint =
        q == null ||
            q.status != GroupQuestStatus.published ||
            group?.archived != false ||
            group?.isActiveMember != true
        ? null
        : group?.isOwner == true
        ? q.scheduledAt.isAfter(DateTime.now())
              ? '시작 시각이 지나면 완료 처리할 수 있어요'
              : null
        : q.scheduledAt.isAfter(DateTime.now())
        ? '시작 시각 이후 그룹장이 완료 처리하면 참여자 전원이 EXP를 받아요'
        : '그룹장이 완료 처리하면 참여자 전원이 EXP를 받아요';
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
                                '일시 · ${q.scheduledAt.year}년 '
                                '${questDateTimeLabel(q.scheduledAt)}',
                                style: LqText.label,
                              ),
                              Text(
                                '작성자 · ${q.creatorNickname}',
                                style: LqText.caption,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${q.participantLabel} · 공동 완료 시 ${q.expReward} EXP',
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
                            label: q.isParticipating
                                ? '참여 신청 취소'
                                : q.isFull
                                ? '정원이 찼어요'
                                : '참여 신청',
                            busy: busy,
                            shadow: !q.isParticipating,
                            borderColor: q.isParticipating
                                ? LqColors.borderMuted
                                : LqColors.ink,
                            // 정원이 찬 뒤에는 눌러도 서버가 거절한다. 누를 수 있는
                            // 것처럼 두지 않고 버튼에 이유를 적는다.
                            onPressed: q.isParticipating
                                ? withdraw
                                : q.isFull
                                ? null
                                : apply,
                          ),
                        ],
                        if (completionHint != null) ...[
                          const SizedBox(height: 16),
                          Text(completionHint, style: LqText.label),
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
                        if (group?.isOwner == true &&
                            q.status == GroupQuestStatus.cancelled) ...[
                          const SizedBox(height: 16),
                          LqButton(
                            label: '퀘스트 영구 삭제',
                            busy: busy,
                            shadow: false,
                            background: LqColors.dangerText,
                            foreground: LqColors.onDark,
                            borderColor: LqColors.ink,
                            onPressed: deletePermanently,
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
