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

class GroupInvitationsScreen extends ConsumerWidget {
  const GroupInvitationsScreen({super.key});
  Future<void> act(
    BuildContext context,
    WidgetRef ref,
    GroupMember m,
    bool accept,
  ) async {
    try {
      final r = ref.read(groupRepositoryProvider);
      if (accept) {
        await r.acceptInvitation(m.memberId);
      } else {
        await r.declineInvitation(m.memberId);
      }
      ref.invalidate(groupInvitationsProvider);
      ref.invalidate(myGroupsProvider);
      if (context.mounted) {
        showLqSnack(context, accept ? '초대를 수락했어요' : '초대를 거절했어요');
      }
    } catch (e) {
      if (context.mounted) showLqError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(groupInvitationsProvider);
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '받은 그룹 초대'),
            Expanded(
              child: LqAsyncView<List<GroupMember>>(
                value: value,
                isEmpty: (v) => v.isEmpty,
                emptyMessage: '받은 초대가 없어요',
                onRetry: () => ref.invalidate(groupInvitationsProvider),
                data: (items) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return LqCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.groupName, style: LqText.cardTitle),
                          Text('그룹 가입 초대', style: LqText.caption),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LqButton(
                                  label: '수락',
                                  onPressed: () => act(context, ref, m, true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LqButton(
                                  label: '거절',
                                  shadow: false,
                                  borderColor: LqColors.borderMuted,
                                  onPressed: () => act(context, ref, m, false),
                                ),
                              ),
                            ],
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
