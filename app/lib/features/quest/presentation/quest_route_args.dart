import 'package:life_quest/features/quest/data/quest_dto.dart';

/// `/quests/:questId` 진입 시 목록이 함께 넘기는 배정 정보.
///
/// 퀘스트 상세 API는 마스터 정보만 주므로, 완료 CTA를 결정하려면
/// 배정 건의 `dailyQuestId`·`status`가 추가로 필요하다.
class QuestDetailArgs {
  const QuestDetailArgs({this.dailyQuestId, this.status});

  final int? dailyQuestId;
  final DailyQuestStatus? status;
}

/// `/quests/:dailyQuestId/verify` 진입 인자.
class QuestVerifyArgs {
  const QuestVerifyArgs({required this.quest});

  final Quest quest;
}
