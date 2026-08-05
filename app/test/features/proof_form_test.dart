import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/proof/application/proof_providers.dart';
import 'package:life_quest/features/proof/data/proof_dto.dart';
import 'package:life_quest/features/proof/data/proof_repository.dart';
import 'package:life_quest/features/proof/presentation/proof_form_args.dart';
import 'package:life_quest/features/proof/presentation/proof_form_screen.dart';

/// 작성 화면의 퀘스트 고정 동작.
///
/// 완료 결과 화면에서 넘어온 경우와 피드의 + 버튼으로 들어온 경우가 서로 다른 화면이어야
/// 한다. 초기값만 채우고 후보 목록을 그대로 띄우면 "이미 정해진 퀘스트"가 "고를 수 있는
/// 퀘스트"로 보여서, 방금 완료한 것이 아닌 다른 완료 기록을 인증해 버릴 수 있다.
void main() {
  testWidgets('완료 결과에서 넘어오면 퀘스트가 읽기 전용으로 고정된다', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProofFormScreen(
          args: ProofFormArgs(
            completionId: 42,
            questTitle: '새로운 카페 방문하기',
            questGrade: 'RARE',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('인증할 퀘스트'), findsOneWidget);
    expect(find.text('새로운 카페 방문하기'), findsOneWidget);
    // 후보 목록이 뜨면 다른 완료 기록을 고를 수 있다는 뜻이다.
    expect(find.text('어떤 퀘스트인가요?'), findsNothing);
    expect(find.text('산책하기'), findsNothing);
  });

  testWidgets('피드에서 바로 들어오면 완료 기록을 목록에서 고른다', (tester) async {
    await tester.pumpWidget(_host(const ProofFormScreen()));
    await tester.pumpAndSettle();

    expect(find.text('어떤 퀘스트인가요?'), findsOneWidget);
    expect(find.text('산책하기'), findsOneWidget);
  });
}

Widget _host(Widget child) => ProviderScope(
  overrides: [
    proofRepositoryProvider.overrideWithValue(_FakeProofRepository()),
  ],
  child: MaterialApp(home: child),
);

class _FakeProofRepository extends ProofRepository {
  _FakeProofRepository() : super(Dio());

  @override
  Future<List<ProofCandidate>> candidates({int size = 20}) async => [
    ProofCandidate(
      completionId: 7,
      questId: 1,
      questTitle: '산책하기',
      questGrade: 'NORMAL',
      completedAt: DateTime(2026, 8, 5, 10),
    ),
  ];
}
