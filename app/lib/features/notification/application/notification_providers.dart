import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_quest/core/storage/local_preferences.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';
import 'package:life_quest/features/notification/data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return const NotificationRepository();
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
    final current = state.value;
    if (current == null) return;

    state = AsyncData({...current, channel: enabled});

    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('$_prefix${channel.key}', enabled);
  }
}
