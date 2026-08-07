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

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myGroupsProvider);
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            // 탭 루트 화면이라 뒤로가기를 두지 않는다.
            const LqHeader(title: '내 그룹', showBack: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: LqButton(
                      label: '그룹 찾기',
                      onPressed: () => context.push('/groups/search'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LqButton(
                      label: '그룹 만들기',
                      onPressed: () => context.push('/groups/create'),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/groups/invitations'),
              child: const Text('받은 초대 보기'),
            ),
            Expanded(
              child: LqAsyncView<List<GroupSummary>>(
                value: value,
                isEmpty: (items) => items.isEmpty,
                emptyMessage: '아직 참여 중인 그룹이 없어요',
                onRetry: () => ref.invalidate(myGroupsProvider),
                data: (groups) => RefreshIndicator(
                  onRefresh: () => ref.refresh(myGroupsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return LqCard(
                        onTap: () => context.push('/groups/${group.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.name, style: LqText.cardTitle),
                            const SizedBox(height: 4),
                            Text(
                              group.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: LqText.bodySm,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${group.activeMemberCount}/${group.maxMembers}명 · ${group.isOwner ? '그룹장' : '멤버'}',
                              style: LqText.caption,
                            ),
                          ],
                        ),
                      );
                    },
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
