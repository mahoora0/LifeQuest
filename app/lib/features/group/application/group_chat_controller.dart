import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/features/group/data/group_repository.dart';

/// 그룹 채팅의 REST polling 상태를 화면과 분리해 보관한다.
///
/// 실시간 전송 수단이 없으므로 화면이 보이는 동안에만 짧은 주기로 새 메시지를
/// 확인한다. 타이머와 중복 제거를 위젯 안에 두면 위젯 트리 없이는 검증할 수
/// 없어서, 폴링 규칙만 따로 떼어 둔다.
class GroupChatController extends ChangeNotifier {
  GroupChatController({required this.repository, required this.groupId});

  final GroupRepository repository;
  final int groupId;

  /// 설계 기준 폴링 주기. 더 짧게 두면 서버 부하만 늘고 체감 차이는 없다.
  static const Duration pollInterval = Duration(seconds: 3);
  static const int maxContentLength = 1000;

  final List<GroupMessage> _messages = [];
  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;

  bool loading = true;
  bool sending = false;
  Object? error;

  List<GroupMessage> get messages => List.unmodifiable(_messages);
  bool get isPolling => _timer?.isActive ?? false;

  Future<void> load() async {
    try {
      final page = await repository.messages(groupId);
      _merge(page.messages);
      loading = false;
      _notify();
      start();
    } catch (e) {
      loading = false;
      error = e;
      _notify();
    }
  }

  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  /// 화면을 벗어나거나 앱이 백그라운드로 갈 때 호출한다.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> poll() async {
    // 한 번의 폴링이 끝나기 전에 다음 폴링을 시작하지 않는다. 느린 응답이
    // 쌓이면 같은 구간을 중복 조회하게 된다.
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final page = await repository.messages(
        groupId,
        afterId: _messages.isEmpty ? null : _messages.last.id,
      );
      _merge(page.messages);
    } catch (_) {
      // 폴링 실패는 조용히 넘긴다. 3초마다 오류를 띄우면 화면을 쓸 수 없다.
    } finally {
      _polling = false;
    }
  }

  /// 전송에 성공하면 true. 서버가 돌려준 메시지를 바로 목록에 붙이고,
  /// 다음 폴링이 같은 메시지를 다시 가져와도 ID로 걸러진다.
  Future<bool> send(String raw) async {
    final content = raw.trim();
    if (content.isEmpty || content.length > maxContentLength || sending) {
      return false;
    }
    sending = true;
    _notify();
    try {
      _merge([await repository.sendMessage(groupId, content)]);
      return true;
    } finally {
      sending = false;
      _notify();
    }
  }

  void _merge(List<GroupMessage> incoming) {
    final ids = _messages.map((message) => message.id).toSet();
    final additions = incoming.where((message) => ids.add(message.id)).toList();
    if (additions.isEmpty) return;
    _messages
      ..addAll(additions)
      ..sort((a, b) => a.id.compareTo(b.id));
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
