import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/group/application/group_chat_controller.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/group/data/group_repository.dart';

void main() {
  test('초기 조회 후 폴링을 시작하고 stop 이후에는 더 조회하지 않는다', () {
    fakeAsync((async) {
      final repository = _FakeChatRepository();
      final controller = _controller(repository);

      controller.load();
      async.flushMicrotasks();
      expect(controller.loading, isFalse);
      expect(controller.isPolling, isTrue);
      expect(repository.messageCalls, 1);

      async.elapse(GroupChatController.pollInterval * 2);
      expect(repository.messageCalls, 3);

      // 화면 이탈. 이후로는 타이머가 돌지 않아야 한다.
      controller.stop();
      expect(controller.isPolling, isFalse);
      async.elapse(GroupChatController.pollInterval * 5);
      expect(repository.messageCalls, 3);

      controller.dispose();
    });
  });

  test('폴링이 같은 ID를 다시 내려줘도 목록에 두 번 담기지 않는다', () {
    fakeAsync((async) {
      final repository = _FakeChatRepository();
      final controller = _controller(repository);

      controller.load();
      async.flushMicrotasks();
      expect(controller.messages.map((m) => m.id), [1, 2]);

      // 서버가 겹치는 구간을 다시 내려주는 상황.
      repository.nextIds = [2, 3];
      async.elapse(GroupChatController.pollInterval);
      expect(controller.messages.map((m) => m.id), [1, 2, 3]);

      controller.stop();
      controller.dispose();
    });
  });

  test('앞선 폴링이 끝나기 전에는 다음 폴링을 시작하지 않는다', () {
    fakeAsync((async) {
      final repository = _FakeChatRepository(
        delay: const Duration(seconds: 10),
      );
      final controller = _controller(repository);

      controller.start();
      async.elapse(GroupChatController.pollInterval * 3);

      // 10초짜리 응답이 아직 안 왔으므로 3초마다 호출이 쌓이면 안 된다.
      expect(repository.messageCalls, 1);

      controller.stop();
      controller.dispose();
    });
  });

  test('공백과 1000자 초과는 전송하지 않는다', () async {
    final repository = _FakeChatRepository();
    final controller = _controller(repository);

    expect(await controller.send('   '), isFalse);
    expect(await controller.send('가' * 1001), isFalse);
    expect(repository.sentContents, isEmpty);

    expect(await controller.send('  보낼 메시지  '), isTrue);
    expect(repository.sentContents, ['보낼 메시지']);
    // 전송 결과는 폴링을 기다리지 않고 바로 목록에 붙는다.
    expect(controller.messages.last.content, '보낼 메시지');

    controller.dispose();
  });
}

GroupChatController _controller(GroupRepository repository) =>
    GroupChatController(repository: repository, groupId: 1);

class _FakeChatRepository extends GroupRepository {
  _FakeChatRepository({this.delay}) : super(Dio());

  final Duration? delay;
  int messageCalls = 0;
  final List<String> sentContents = [];
  List<int> nextIds = const [];

  @override
  Future<GroupMessagePage> messages(
    int id, {
    int? beforeId,
    int? afterId,
  }) async {
    messageCalls++;
    if (delay != null) await Future<void>.delayed(delay!);
    final ids = afterId == null ? const [1, 2] : nextIds;
    return GroupMessagePage(
      messages: [
        for (final messageId in ids) _message(messageId, '메시지$messageId'),
      ],
      hasMoreBefore: false,
      latestId: ids.isEmpty ? afterId : ids.last,
    );
  }

  @override
  Future<GroupMessage> sendMessage(int id, String content) async {
    sentContents.add(content);
    return _message(99, content, mine: true);
  }
}

GroupMessage _message(int id, String content, {bool mine = false}) =>
    GroupMessage(
      id: id,
      senderUserId: mine ? 1 : 2,
      senderNickname: mine ? '나' : '정원',
      content: content,
      mine: mine,
      createdAt: DateTime(2026, 8, 4, 15),
    );
