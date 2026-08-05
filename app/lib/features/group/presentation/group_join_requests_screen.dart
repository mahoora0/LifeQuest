import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/design/lq_tokens.dart';
import 'package:life_quest/shared/widgets/lq_async_view.dart';
import 'package:life_quest/shared/widgets/lq_button.dart';
import 'package:life_quest/shared/widgets/lq_card.dart';
import 'package:life_quest/shared/widgets/lq_header.dart';
import 'package:life_quest/shared/widgets/lq_snack.dart';

class GroupJoinRequestsScreen extends ConsumerWidget {
  const GroupJoinRequestsScreen({required this.groupId, super.key});
  final int groupId;
  Future<void> act(
    BuildContext c,
    WidgetRef ref,
    GroupMember m,
    bool approve,
  ) async {
    try {
      final r = ref.read(groupRepositoryProvider);
      if (approve) {
        await r.approveJoin(groupId, m.memberId);
      } else {
        await r.rejectJoin(groupId, m.memberId);
      }
      ref.invalidate(groupJoinRequestsProvider(groupId));
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupDetailProvider(groupId));
    } catch (e) {
      if (c.mounted) showLqError(c, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(groupJoinRequestsProvider(groupId));
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '가입 승인'),
            Expanded(
              child: LqAsyncView<List<GroupMember>>(
                value: value,
                isEmpty: (v) => v.isEmpty,
                emptyMessage: '대기 중인 가입 요청이 없어요',
                onRetry: () =>
                    ref.invalidate(groupJoinRequestsProvider(groupId)),
                data: (items) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return LqCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(m.nickname, style: LqText.cardTitle),
                          ),
                          SizedBox(
                            width: 72,
                            child: LqButton(
                              label: '승인',
                              fontSize: 13,
                              onPressed: () => act(context, ref, m, true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 72,
                            child: LqButton(
                              label: '거절',
                              fontSize: 13,
                              shadow: false,
                              onPressed: () => act(context, ref, m, false),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
