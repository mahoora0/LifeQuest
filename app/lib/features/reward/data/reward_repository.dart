import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/reward/data/reward_dto.dart';

/// 레벨 · 보상 조회.
///
/// **엔드포인트는 있으나 응답이 이 화면에 모자란다.** `GET /users/me/rewards`는
/// 존재하지만(`UserController.java:109`) `{titles, profileItems}`만 돌려줘서,
/// S-05가 필요한 레벨·다음 관문·획득 시점·주간 EXP가 전부 빠져 있다. 부분만 실데이터로
/// 채우면 어느 수치가 진짜인지 화면에서 구분되지 않으므로 준비 중 상태를 표시한다.
///
// TODO(server): RewardHistoryResponse에 레벨·다음 관문·획득 시점(acquiredAt)·주간
//  EXP를 더한 뒤, fetchOverview를 UserRepository.fetchRewards와 같은 실호출로 바꾸고
//  실제 응답을 표시한다. 지금 응답으로는 "받은 보상" 목록조차 언제 받았는지 알 수 없다.
// TODO(server): questsToNextLevel(남은 EXP ÷ 평균 퀘스트 보상)은 서버 계산값이다.
//  응답에 없으면 화면이 해당 문구를 감춘다 — 클라이언트에서 추정하지 않는다.
class RewardRepository {
  const RewardRepository();

  Future<RewardOverview> fetchOverview() async => throw const ApiException(
    code: 'ENDPOINT_NOT_FOUND',
    message: '레벨 · 보상은 아직 준비 중이에요.',
    statusCode: 404,
  );
}
