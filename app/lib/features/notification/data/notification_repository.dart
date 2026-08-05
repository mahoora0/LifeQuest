import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/notification/data/notification_dto.dart';

/// 알림 목록 조회와 읽음 처리를 담당한다.
class NotificationRepository {
  const NotificationRepository([this._dio]);

  final Dio? _dio;

  Dio get _client =>
      _dio ?? (throw StateError('NotificationRepository requires Dio'));

  Future<LqNotificationFeed> fetchFeed() => _guard(() async {
    final response = await _client.get<dynamic>(
      '/notifications',
      queryParameters: const {'page': 0, 'size': 100},
    );
    return LqNotificationFeed.fromJson(response.data);
  });

  /// 한 건이면 해당 알림만, 여러 건이면 서버의 모두 읽음 API로 처리한다.
  Future<void> markRead(List<int> ids) async {
    if (_dio == null || ids.isEmpty) return;
    await _guard(() async {
      if (ids.length == 1) {
        await _client.patch<dynamic>('/notifications/${ids.single}/read');
      } else {
        await _client.patch<dynamic>('/notifications/read');
      }
    });
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
