import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';
import 'package:life_quest/shared/data/sample_data.dart';

/// 친구·친구 요청·검색·랭킹 API 접근 계층.
///
/// [dio]를 선택 인자로 둔 것은 위젯 테스트의 가짜 저장소가 네트워크 클라이언트
/// 없이 이 클래스를 상속할 수 있게 하기 위해서다. 실제 앱 provider는 항상 Dio를
/// 주입한다.
class FriendRepository {
  const FriendRepository([this._dio]);

  final Dio? _dio;

  Dio get _client =>
      _dio ?? (throw StateError('FriendRepository requires Dio'));

  Future<FriendList> fetchFriends() => _guard(() async {
    final responses = await Future.wait([
      _client.get<dynamic>(
        '/friends',
        queryParameters: const {'page': 0, 'size': 100},
      ),
      _client.get<dynamic>('/users/me/friend-code'),
    ]);
    final friends = FriendList.fromJson(responses[0].data);
    final code = asString(
      pick(asMap(responses[1].data), ['friendCode', 'code']),
    );
    return FriendList(friends: friends.friends, myCode: code);
  });

  Future<WeeklyRanking> fetchWeeklyRanking({
    RankingType type = RankingType.exp,
  }) => _guard(() async {
    final response = await _client.get<dynamic>(
      '/rankings/friends',
      queryParameters: {'page': 0, 'size': 100, 'type': type.apiValue},
    );
    return WeeklyRanking.fromJson(response.data);
  });

  /// 현재 백엔드에는 친구 코드 개념이 없다. 화면은 null이면 코드 영역을 숨긴다.
  Future<String?> fetchMyCode() => _guard(() async {
    final response = await _client.get<dynamic>('/users/me/friend-code');
    return asString(pick(asMap(response.data), ['friendCode', 'code']));
  });

  Future<List<AdventurerSearchResult>> searchAdventurers(String query) =>
      _guard(() async {
        final response = await _client.get<dynamic>(
          '/users/search',
          queryParameters: {'query': query, 'page': 0, 'size': 100},
        );
        final body = asMap(response.data);
        final results = asMapList(
          pick(body, ['content', 'items']),
        ).map(AdventurerSearchResult.fromJson).toList();
        final friends = await fetchFriends();
        final requests = await fetchRequests();
        final friendIds = friends.friends
            .map((friend) => friend.userId)
            .toSet();
        final sentIds = requests.sent.map((request) => request.userId).toSet();
        final receivedIds = requests.received
            .map((request) => request.userId)
            .toSet();
        return [
          for (final result in results)
            result.copyWith(
              relation: friendIds.contains(result.userId)
                  ? FriendRelation.friend
                  : sentIds.contains(result.userId)
                  ? FriendRelation.requestSent
                  : receivedIds.contains(result.userId)
                  ? FriendRelation.requestReceived
                  : FriendRelation.none,
            ),
        ];
      });

  Future<void> sendRequest(int userId) async {
    if (_dio == null) return;
    await _guard(() async {
      await _client.post<dynamic>(
        '/friends/requests',
        data: {'receiverId': userId},
      );
    });
  }

  Future<FriendRequestBox> fetchRequests() => _guard(() async {
    final responses = await Future.wait([
      _client.get<dynamic>(
        '/friends/requests',
        queryParameters: const {'page': 0, 'size': 100},
      ),
      _client.get<dynamic>(
        '/friends/requests/sent',
        queryParameters: const {'page': 0, 'size': 100},
      ),
    ]);
    return FriendRequestBox(
      received: _requestItems(responses[0].data),
      sent: _requestItems(responses[1].data),
    );
  });

  Future<void> respondToRequest(int requestId, {required bool accept}) async {
    if (_dio == null) return;
    await _guard(() async {
      await _client.patch<dynamic>(
        '/friends/requests/$requestId',
        data: {'action': accept ? 'ACCEPT' : 'REJECT'},
      );
    });
  }

  /// 업적·도감 비교 API가 완성될 때까지 기존 준비 중 상태를 유지한다.
  Future<FriendJourney> fetchJourney(int userId) async {
    LqSampleData.guard('친구의 여정');
    throw StateError('Friend journey sample is not configured');
  }

  Future<void> unfriend(int userId) => _guard(() async {
    await _client.delete<dynamic>('/friends/$userId');
  });

  /// 응원은 아직 서버 계약이 없어 기존 화면 동작만 유지한다.
  Future<void> cheer(int userId) async {}

  List<FriendRequest> _requestItems(Object? body) {
    final json = asMap(body);
    return asMapList(
      pick(json, ['content', 'items']),
    ).map(FriendRequest.fromJson).toList();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
