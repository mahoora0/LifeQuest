import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_quest/features/group/application/group_providers.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/group/data/group_repository.dart';
import 'package:life_quest/features/group/presentation/group_chat_screen.dart';
import 'package:life_quest/features/group/presentation/group_detail_screen.dart';
import 'package:life_quest/features/group/presentation/group_form_screen.dart';
import 'package:life_quest/features/group/presentation/group_invitations_screen.dart';
import 'package:life_quest/features/group/presentation/group_join_requests_screen.dart';
import 'package:life_quest/features/group/presentation/group_list_screen.dart';
import 'package:life_quest/features/group/presentation/group_members_screen.dart';
import 'package:life_quest/features/group/presentation/group_quest_detail_screen.dart';
import 'package:life_quest/features/group/presentation/group_quest_form_screen.dart';
import 'package:life_quest/features/group/presentation/group_search_screen.dart';

void main() {
  testWidgets('내 그룹 목록에 역할과 인원 및 주요 진입점을 표시한다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(tester, const GroupListScreen(), repository);

    expect(find.text('주말 탐험대'), findsOneWidget);
    expect(find.text('2/10명 · 그룹장'), findsOneWidget);
    expect(find.text('그룹 찾기'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);
    expect(find.text('받은 초대 보기'), findsOneWidget);
  });

  testWidgets('공개 그룹 검색은 가입 가능·대기·마감 상태를 구분한다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(tester, const GroupSearchScreen(), repository);

    await tester.enterText(find.byType(TextField), '탐험');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();

    expect(find.text('가입 요청'), findsOneWidget);
    expect(find.text('승인 대기'), findsOneWidget);
    expect(find.text('정원 마감'), findsOneWidget);
    await tester.tap(find.text('가입 요청'));
    await tester.pumpAndSettle();
    expect(repository.joinedGroupIds, [2]);
    expect(find.text('가입 요청을 보냈어요'), findsOneWidget);
  });

  testWidgets('그룹장은 이름·공개 여부·최대 인원을 선택해 그룹을 만든다', (tester) async {
    final repository = _FakeGroupRepository();
    final router = GoRouter(
      initialLocation: '/groups/create',
      routes: [
        GoRoute(
          path: '/groups/create',
          builder: (_, _) => const GroupFormScreen(),
        ),
        GoRoute(
          path: '/groups/:id',
          builder: (_, state) => Text('생성 그룹 ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('그룹 만들기').last);
    await tester.pump();
    expect(repository.createCalls, 0);
    expect(
      find.text('이름 2~100자, 설명 1~500자, 정원 2~100명을 확인해 주세요'),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, '그룹 이름'), '저녁 산책단');
    await tester.enterText(find.widgetWithText(TextField, '설명'), '퇴근 후 함께 걸어요');
    await tester.enterText(
      find.widgetWithText(TextField, '최대 인원 (2~100)'),
      '7',
    );
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('그룹 만들기').last);
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.createdName, '저녁 산책단');
    expect(repository.createdMaxMembers, 7);
    expect(repository.createdVisibility, GroupVisibility.private);
    expect(find.text('생성 그룹 9'), findsOneWidget);
  });

  testWidgets('받은 초대를 수락하면 저장소를 호출하고 결과를 안내한다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(tester, const GroupInvitationsScreen(), repository);

    expect(find.text('초대받은 그룹'), findsOneWidget);
    await tester.tap(find.text('수락'));
    await tester.pumpAndSettle();

    expect(repository.acceptedInvitationIds, [21]);
    expect(find.text('초대를 수락했어요'), findsOneWidget);
  });

  testWidgets('그룹장은 가입 요청을 승인하거나 거절할 수 있다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(tester, const GroupJoinRequestsScreen(groupId: 1), repository);

    expect(find.text('가입대기자'), findsOneWidget);
    await tester.tap(find.text('승인'));
    await tester.pumpAndSettle();
    expect(repository.approvedMemberIds, [31]);
  });

  testWidgets('그룹장은 사용자를 초대하고 멤버에게 그룹장을 위임할 수 있다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(tester, const GroupMembersScreen(groupId: 1), repository);

    await tester.enterText(find.byType(TextField), '새멤버');
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('초대대상'), findsOneWidget);
    await tester.tap(find.text('초대'));
    await tester.pumpAndSettle();
    expect(repository.invitedUserIds, [12]);

    await tester.tap(find.byType(PopupMenuButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그룹장 위임'));
    await tester.pumpAndSettle();
    expect(repository.transferredUserIds, [8]);
  });

  testWidgets('보관된 그룹 상세는 기록만 보여주고 변경 진입점을 감춘다', (tester) async {
    final repository = _FakeGroupRepository(archived: true);
    await _pump(tester, const GroupDetailScreen(groupId: 1), repository);

    expect(find.text('보관된 그룹 · 읽기 전용'), findsOneWidget);
    expect(find.text('멤버'), findsOneWidget);
    expect(find.text('채팅'), findsOneWidget);
    expect(find.text('새 퀘스트'), findsNothing);
    expect(find.text('가입 승인 관리'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
  });

  testWidgets('채팅은 폴링 결과를 중복 없이 합치고 전송 결과를 즉시 표시한다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(tester, const GroupChatScreen(groupId: 1), repository);

    expect(find.text('첫 메시지'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('첫 메시지'), findsOneWidget);
    expect(find.text('새 메시지'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '직접 보낸 메시지');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(repository.sentContents, ['직접 보낸 메시지']);
    expect(find.text('직접 보낸 메시지'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('보관된 그룹 채팅은 입력 없이 읽기 전용 안내를 표시한다', (tester) async {
    final repository = _FakeGroupRepository(archived: true);
    await _pump(tester, const GroupChatScreen(groupId: 1), repository);

    expect(find.text('보관된 그룹은 채팅 기록만 볼 수 있어요.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('그룹 퀘스트 입력을 검증하고 미래 일정으로 저장한다', (tester) async {
    final repository = _FakeGroupRepository();
    final router = GoRouter(
      initialLocation: '/groups/1/quests/create',
      routes: [
        GoRoute(
          path: '/groups/1/quests/create',
          builder: (_, _) => const GroupQuestFormScreen(groupId: 1),
        ),
        GoRoute(
          path: '/groups/1/quests/:id',
          builder: (_, state) => Text('저장 퀘스트 ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(repository.savedQuestTitles, isEmpty);
    expect(find.text('제목·설명·장소와 미래 일시를 확인해 주세요'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '제목'), '한강 야경 산책');
    await tester.enterText(find.widgetWithText(TextField, '설명'), '함께 한강을 걸어요');
    await tester.enterText(find.widgetWithText(TextField, '장소'), '여의도 한강공원');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(repository.savedQuestTitles, ['한강 야경 산책']);
    expect(repository.savedScheduledAt.single.isAfter(DateTime.now()), isTrue);
    expect(find.text('저장 퀘스트 41'), findsOneWidget);
  });

  testWidgets('그룹 퀘스트를 취소하면 편집 동작이 사라지고 취소 상태를 표시한다', (tester) async {
    final repository = _FakeGroupRepository();
    await _pump(
      tester,
      const GroupQuestDetailScreen(groupId: 1, questId: 41),
      repository,
    );

    expect(find.text('한강 야경 산책'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.text('퀘스트 취소'), findsOneWidget);
    await tester.tap(find.text('퀘스트 취소'));
    await tester.pumpAndSettle();

    expect(repository.cancelledQuestIds, [41]);
    expect(find.text('취소된 퀘스트'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.text('퀘스트 취소'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _FakeGroupRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeGroupRepository extends GroupRepository {
  _FakeGroupRepository({this.archived = false}) : super(Dio());
  final bool archived;
  int createCalls = 0;
  String? createdName;
  int? createdMaxMembers;
  GroupVisibility? createdVisibility;
  final joinedGroupIds = <int>[];
  final acceptedInvitationIds = <int>[];
  final approvedMemberIds = <int>[];
  final invitedUserIds = <int>[];
  final transferredUserIds = <int>[];
  final sentContents = <String>[];
  final savedQuestTitles = <String>[];
  final savedScheduledAt = <DateTime>[];
  final cancelledQuestIds = <int>[];
  int messageCalls = 0;

  @override
  Future<List<GroupSummary>> myGroups() async => [_summary(id: 1, owner: true)];

  @override
  Future<List<GroupSummary>> search(String query) async => [
    _summary(id: 2),
    _summary(id: 3, membership: GroupMembershipStatus.pendingApproval),
    _summary(id: 4, joinable: false),
  ];

  @override
  Future<GroupDetail> detail(int id) async => _detail(archived: archived);

  @override
  Future<GroupDetail> create({
    required String name,
    required String description,
    required GroupVisibility visibility,
    required int maxMembers,
  }) async {
    createCalls++;
    createdName = name;
    createdMaxMembers = maxMembers;
    createdVisibility = visibility;
    return _detail(id: 9, name: name);
  }

  @override
  Future<void> join(int id) async => joinedGroupIds.add(id);

  @override
  Future<List<GroupMember>> invitations() async => [_invitation()];

  @override
  Future<void> acceptInvitation(int memberId) async {
    acceptedInvitationIds.add(memberId);
  }

  @override
  Future<List<GroupMember>> joinRequests(int id) async => [_pendingMember()];

  @override
  Future<List<GroupMember>> members(int id) async => [
    _member(),
    _activeMember(),
  ];

  @override
  Future<List<GroupUserLookup>> searchUsers(String nickname) async => const [
    GroupUserLookup(id: 12, nickname: '초대대상', level: 4),
  ];

  @override
  Future<void> invite(int id, int userId) async {
    invitedUserIds.add(userId);
  }

  @override
  Future<void> transfer(int id, int userId) async {
    transferredUserIds.add(userId);
  }

  @override
  Future<void> approveJoin(int id, int memberId) async {
    approvedMemberIds.add(memberId);
  }

  @override
  Future<List<GroupQuest>> quests(int id, {required bool upcoming}) async => [];

  @override
  Future<GroupQuest> quest(int id, int questId) async => _quest(
    status: cancelledQuestIds.contains(questId)
        ? GroupQuestStatus.cancelled
        : GroupQuestStatus.published,
  );

  @override
  Future<GroupQuest> saveQuest(
    int id, {
    int? questId,
    required String title,
    required String description,
    required String placeName,
    required DateTime scheduledAt,
  }) async {
    savedQuestTitles.add(title);
    savedScheduledAt.add(scheduledAt);
    return _quest(title: title);
  }

  @override
  Future<void> cancelQuest(int id, int questId) async {
    cancelledQuestIds.add(questId);
  }

  @override
  Future<GroupMessagePage> messages(
    int id, {
    int? beforeId,
    int? afterId,
  }) async {
    messageCalls++;
    if (afterId != null) {
      return GroupMessagePage(
        messages: [_message(1, '첫 메시지'), _message(2, '새 메시지')],
        hasMoreBefore: false,
        latestId: 2,
      );
    }
    return GroupMessagePage(
      messages: [_message(1, '첫 메시지')],
      hasMoreBefore: false,
      latestId: 1,
    );
  }

  @override
  Future<GroupMessage> sendMessage(int id, String content) async {
    sentContents.add(content);
    return _message(3, content, mine: true);
  }
}

GroupSummary _summary({
  required int id,
  bool owner = false,
  bool joinable = true,
  GroupMembershipStatus? membership,
}) => GroupSummary(
  id: id,
  name: id == 1 ? '주말 탐험대' : '검색 그룹 $id',
  description: '함께 경험해요',
  activeMemberCount: id == 1 ? 2 : 1,
  maxMembers: id == 1 ? 10 : 3,
  joinable: joinable,
  myRole: owner ? GroupRole.owner : null,
  myMembershipStatus: owner ? GroupMembershipStatus.active : membership,
  status: GroupStatus.active,
);

GroupDetail _detail({
  int id = 1,
  String name = '주말 탐험대',
  bool archived = false,
}) => GroupDetail(
  id: id,
  name: name,
  description: '함께 경험해요',
  visibility: GroupVisibility.public,
  maxMembers: 10,
  activeMemberCount: 1,
  status: archived ? GroupStatus.archived : GroupStatus.active,
  ownerUserId: 1,
  ownerNickname: '그룹장',
  joinable: !archived,
  members: [_member()],
  recentQuests: const [],
  myRole: GroupRole.owner,
  myMembershipStatus: GroupMembershipStatus.active,
);

GroupMember _member() => const GroupMember(
  memberId: 1,
  groupId: 1,
  groupName: '주말 탐험대',
  userId: 1,
  nickname: '그룹장',
  role: GroupRole.owner,
  status: GroupMembershipStatus.active,
);

GroupMember _invitation() => const GroupMember(
  memberId: 21,
  groupId: 5,
  groupName: '초대받은 그룹',
  userId: 1,
  nickname: '사용자',
  role: GroupRole.member,
  status: GroupMembershipStatus.invited,
);

GroupMember _pendingMember() => const GroupMember(
  memberId: 31,
  groupId: 1,
  groupName: '주말 탐험대',
  userId: 8,
  nickname: '가입대기자',
  role: GroupRole.member,
  status: GroupMembershipStatus.pendingApproval,
);

GroupMember _activeMember() => const GroupMember(
  memberId: 32,
  groupId: 1,
  groupName: '주말 탐험대',
  userId: 8,
  nickname: '활동멤버',
  role: GroupRole.member,
  status: GroupMembershipStatus.active,
);

GroupQuest _quest({
  String title = '한강 야경 산책',
  GroupQuestStatus status = GroupQuestStatus.published,
}) => GroupQuest(
  id: 41,
  groupId: 1,
  createdByUserId: 1,
  creatorNickname: '그룹장',
  title: title,
  description: '함께 한강을 걸어요',
  placeName: '여의도 한강공원',
  scheduledAt: DateTime.now().add(const Duration(days: 2)),
  status: status,
);

GroupMessage _message(int id, String content, {bool mine = false}) =>
    GroupMessage(
      id: id,
      senderUserId: mine ? 1 : 2,
      senderNickname: mine ? '나' : '동료',
      content: content,
      mine: mine,
      createdAt: DateTime(2026, 8, 4, 12, id),
    );
