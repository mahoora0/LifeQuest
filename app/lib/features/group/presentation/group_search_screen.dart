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

class GroupSearchScreen extends ConsumerStatefulWidget {
  const GroupSearchScreen({super.key});
  @override
  ConsumerState<GroupSearchScreen> createState() => _GroupSearchState();
}

class _GroupSearchState extends ConsumerState<GroupSearchScreen> {
  final controller = TextEditingController();
  List<GroupSummary> results = const [];
  bool busy = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;
    setState(() => busy = true);
    try {
      final found = await ref.read(groupRepositoryProvider).search(query);
      if (mounted) setState(() => results = found);
    } catch (error) {
      if (mounted) showLqError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> join(GroupSummary group) async {
    try {
      await ref.read(groupRepositoryProvider).join(group.id);
      if (mounted) {
        showLqSnack(context, '가입 요청을 보냈어요');
        await search();
      }
    } catch (error) {
      if (mounted) showLqError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LqColors.surfacePanel,
      body: SafeArea(
        child: Column(
          children: [
            const LqHeader(title: '공개 그룹 찾기'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: (_) => search(),
                      decoration: const InputDecoration(
                        labelText: '그룹 이름 또는 설명',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: LqButton(label: '검색', busy: busy, onPressed: search),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('검색 결과가 없어요'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = results[index];
                        final canJoin =
                            group.joinable && group.myMembershipStatus == null;
                        final label =
                            group.myMembershipStatus ==
                                GroupMembershipStatus.pendingApproval
                            ? '승인 대기'
                            : group.joinable
                            ? '가입 요청'
                            : '정원 마감';
                        return LqCard(
                          onTap: () => context.push('/groups/${group.id}'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(group.name, style: LqText.cardTitle),
                                    Text(
                                      group.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${group.activeMemberCount}/${group.maxMembers}명',
                                      style: LqText.caption,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 86,
                                child: LqButton(
                                  label: label,
                                  fontSize: 13,
                                  onPressed: canJoin ? () => join(group) : null,
                                ),
                              ),
                            ],
                          ),
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
