import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/proof/application/proof_providers.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/data/proof_repository.dart';
import 'package:life_quest/features/proof/presentation/proof_feed_screen.dart';

void main() {
  testWidgets('주제 칩을 누르면 해당 카테고리로 피드를 다시 조회한다', (tester) async {
    final repository = _RecordingProofRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [proofRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ProofFeedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('모든 주제'), findsOneWidget);
    expect(repository.categories.last, isNull);

    await tester.tap(find.text('건강·운동'));
    await tester.pumpAndSettle();

    expect(repository.categories.last, ProofQuestCategory.healthFitness);
    expect(tester.takeException(), isNull);
  });

  test('탭·주제 조합별 목록과 커서가 독립적이다', () async {
    final repository = _PagingProofRepository();
    final container = ProviderContainer(
      overrides: [proofRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    const ProofFeedFilter first = (
      tab: ProofFeedTab.needsVote,
      category: ProofQuestCategory.healthFitness,
    );
    const ProofFeedFilter otherTab = (
      tab: ProofFeedTab.all,
      category: ProofQuestCategory.healthFitness,
    );
    const ProofFeedFilter otherCategory = (
      tab: ProofFeedTab.needsVote,
      category: ProofQuestCategory.foodCafe,
    );

    final firstSubscription = container.listen(
      proofFeedProvider(first),
      (_, _) {},
    );
    addTearDown(firstSubscription.close);
    await container.read(proofFeedProvider(first).future);
    await container.read(proofFeedProvider(first).notifier).loadMore();
    final tabSubscription = container.listen(
      proofFeedProvider(otherTab),
      (_, _) {},
    );
    addTearDown(tabSubscription.close);
    await container.read(proofFeedProvider(otherTab).future);
    final categorySubscription = container.listen(
      proofFeedProvider(otherCategory),
      (_, _) {},
    );
    addTearDown(categorySubscription.close);
    await container.read(proofFeedProvider(otherCategory).future);

    expect(repository.requests, [
      (tab: first.tab, category: first.category, cursor: null),
      (tab: first.tab, category: first.category, cursor: 100),
      (tab: otherTab.tab, category: otherTab.category, cursor: null),
      (tab: otherCategory.tab, category: otherCategory.category, cursor: null),
    ]);
  });
}

class _RecordingProofRepository extends ProofRepository {
  _RecordingProofRepository() : super(Dio());

  final categories = <ProofQuestCategory?>[];

  @override
  Future<ProofFeedPage> feed({
    required ProofFeedTab tab,
    ProofQuestCategory? category,
    int? cursor,
    int size = 10,
  }) async {
    categories.add(category);
    return const ProofFeedPage(items: []);
  }
}

class _PagingProofRepository extends ProofRepository {
  _PagingProofRepository() : super(Dio());

  final requests =
      <({ProofFeedTab tab, ProofQuestCategory? category, int? cursor})>[];

  @override
  Future<ProofFeedPage> feed({
    required ProofFeedTab tab,
    ProofQuestCategory? category,
    int? cursor,
    int size = 10,
  }) async {
    requests.add((tab: tab, category: category, cursor: cursor));
    return ProofFeedPage(
      items: const [],
      nextCursor: cursor == null ? 100 : null,
    );
  }
}
