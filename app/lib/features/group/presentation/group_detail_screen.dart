import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});
  final int groupId;
  Future<void> _join(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(groupRepositoryProvider).join(groupId);
      ref.invalidate(groupDetailProvider(groupId));
      if (context.mounted) showLqSnack(context, '가입 요청을 보냈어요');
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(groupRepositoryProvider).leave(groupId);
      ref.invalidate(myGroupsProvider);
      if (context.mounted) context.go('/groups');
    } catch (error) {
      if (context.mounted) showLqError(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(groupDetailProvider(groupId));
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            LqHeader(
              title: '그룹 상세',
              trailing:
                  value.value?.isOwner == true && value.value?.archived == false
                  ? LqIconButton(
                      icon: Icons.edit,
                      onTap: () => context.push('/groups/$groupId/edit'),
                    )
                  : null,
            ),
            Expanded(
              child: LqAsyncView<GroupDetail>(
                value: value,
                emptyMessage: '그룹을 찾을 수 없어요',
                onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
                data: (group) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      LqCard(
                        header: group.name,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.description, style: LqText.body),
                            const SizedBox(height: 8),
                            Text(
                              '그룹장 ${group.ownerNickname} · ${group.activeMemberCount}/${group.maxMembers}명',
                              style: LqText.caption,
                            ),
                            Text(
                              group.visibility == GroupVisibility.public
                                  ? '공개 그룹'
                                  : '비공개 그룹',
                              style: LqText.caption,
                            ),
                            if (group.archived)
                              Text(
                                '보관된 그룹 · 읽기 전용',
                                style: LqText.label.copyWith(
                                  color: LqColors.warnText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!group.isActiveMember && group.joinable)
                        LqButton(
                          label:
                              group.myMembershipStatus ==
                                  GroupMembershipStatus.pendingApproval
                              ? '승인 대기 중'
                              : '가입 요청',
                          onPressed: group.myMembershipStatus == null
                              ? () => _join(context, ref)
                              : null,
                        ),
                      if (group.isActiveMember) ...[
                        Row(
                          children: [
                            Expanded(
                              child: LqButton(
                                label: '멤버',
                                onPressed: () =>
                                    context.push('/groups/$groupId/members'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LqButton(
                                label: '채팅',
                                onPressed: () =>
                                    context.push('/groups/$groupId/chat'),
                              ),
                            ),
                          ],
                        ),
                        if (group.isOwner && !group.archived) ...[
                          const SizedBox(height: 8),
                          LqButton(
                            label: '가입 승인 관리',
                            onPressed: () =>
                                context.push('/groups/$groupId/join-requests'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('예정 그룹 퀘스트', style: LqText.sectionTitle),
                            if (group.isOwner && !group.archived)
                              TextButton(
                                onPressed: () => context.push(
                                  '/groups/$groupId/quests/create',
                                ),
                                child: const Text('새 퀘스트'),
                              ),
                          ],
                        ),
                        _QuestSection(groupId: groupId, upcoming: true),
                        const SizedBox(height: 12),
                        Text('지난·취소 퀘스트', style: LqText.sectionTitle),
                        _QuestSection(groupId: groupId, upcoming: false),
                        if (!group.isOwner && !group.archived) ...[
                          const SizedBox(height: 20),
                          LqButton(
                            label: '그룹 탈퇴',
                            shadow: false,
                            borderColor: LqColors.borderMuted,
                            onPressed: () => _leave(context, ref),
                          ),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestSection extends ConsumerWidget {
  const _QuestSection({required this.groupId, required this.upcoming});
  final int groupId;
  final bool upcoming;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(
      upcoming
          ? upcomingGroupQuestsProvider(groupId)
          : pastGroupQuestsProvider(groupId),
    );
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: CircularProgressIndicator(),
      ),
      error: (_, _) => Text('퀘스트를 불러오지 못했어요', style: LqText.caption),
      data: (items) => items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('표시할 퀘스트가 없어요', style: LqText.caption),
            )
          : Column(
              children: [
                for (final quest in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LqCard(
                      onTap: () =>
                          context.push('/groups/$groupId/quests/${quest.id}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(quest.title, style: LqText.cardTitle),
                                Text(quest.placeName, style: LqText.caption),
                              ],
                            ),
                          ),
                          Text(
                            '${quest.scheduledAt.month}/${quest.scheduledAt.day}',
                            style: LqText.label,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
