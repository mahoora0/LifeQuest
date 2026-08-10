import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/network/api_client.dart';
import 'package:life_quest/core/storage/local_preferences.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/features/notification/data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(dioProvider));
});

/// 알림 목록. 읽음 상태를 화면에서 바꿔야 해서 Notifier로 둔다.
final notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeedNotifier, LqNotificationFeed>(
      NotificationFeedNotifier.new,
    );

class NotificationFeedNotifier extends AsyncNotifier<LqNotificationFeed> {
  @override
  Future<LqNotificationFeed> build() {
    return ref.watch(notificationRepositoryProvider).fetchFeed();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).fetchFeed(),
    );
  }

  /// 한 건 읽음. 화면을 먼저 바꾸고 실패하면 서버 상태로 되돌린다.
  Future<void> markRead(int id) => _mark([id]);

  /// 모두 읽음. 읽지 않은 것이 없으면 아무 일도 하지 않는다.
  Future<void> markAllRead() {
    final current = state.value;
    if (current == null) return Future.value();
    return _mark([
      for (final item in current.items)
        if (!item.read) item.id,
    ]);
  }

  Future<void> _mark(List<int> ids) async {
    final current = state.value;
    if (current == null || ids.isEmpty) return;

    state = AsyncData(
      LqNotificationFeed(
        items: [
          for (final item in current.items)
            ids.contains(item.id) ? item.copyWith(read: true) : item,
        ],
        serverUnreadCount: ids.length == 1
            ? (current.unreadCount - 1).clamp(0, current.unreadCount)
            : 0,
      ),
    );

    try {
      await ref.read(notificationRepositoryProvider).markRead(ids);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// 알림 수신 토글.
///
/// 서버에 알림 설정 API가 없어 기기에 저장한다. API가 열리면 이 Notifier의
/// 읽기·쓰기만 서버 호출로 바꾸면 화면은 그대로다.
final notificationSettingsProvider =
    AsyncNotifierProvider<
      NotificationSettingsNotifier,
      Map<LqNotificationChannel, bool>
    >(NotificationSettingsNotifier.new);

class NotificationSettingsNotifier
    extends AsyncNotifier<Map<LqNotificationChannel, bool>> {
  static const _prefix = 'notification.channel.';

  @override
  Future<Map<LqNotificationChannel, bool>> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return {
      for (final channel in LqNotificationChannel.values)
        channel: prefs.getBool('$_prefix${channel.key}') ?? channel.defaultOn,
    };
  }

  Future<void> toggle(LqNotificationChannel channel, bool enabled) async {
    // 값을 읽기 전에도 화면은 기본값으로 스위치를 그려 두므로 탭이 들어올 수 있다.
    // `null`이면 그냥 버리던 것을 기본값 위에 얹어 처리한다 — 누른 스위치가
    // 아무 반응 없이 되돌아가면 고장으로 읽힌다.
    final current =
        state.value ??
        {for (final each in LqNotificationChannel.values) each: each.defaultOn};

    state = AsyncData({...current, channel: enabled});

    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.setBool('$_prefix${channel.key}', enabled);
    } catch (error, stackTrace) {
      // 저장에 실패했는데 스위치를 켠 채로 두면, 다시 열었을 때 조용히 되돌아가
      // 사용자는 언제 꺼졌는지 모른다. 다른 낙관적 갱신과 같이 되돌린다.
      state = AsyncData({...current, channel: !enabled});
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
