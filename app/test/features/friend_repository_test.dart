import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_quest/features/friends/data/friend_dto.dart';
import 'package:life_quest/features/friends/data/friend_repository.dart';

void main() {
  test('내 친구 코드를 서버에서 조회한다', () async {
    final dio = _dio((options) {
      expect(options.path, '/users/me/friend-code');
      return {'friendCode': 'LQ-0000002A'};
    });

    final code = await FriendRepository(dio).fetchMyCode();

    expect(code, 'LQ-0000002A');
  });

  test('친구 코드를 공통 검색어 query로 전달한다', () async {
    String? searchQuery;
    final dio = _dio((options) {
      if (options.path == '/users/search') {
        searchQuery = options.queryParameters['query'] as String?;
      }
      return {'content': <Object>[]};
    });

    await FriendRepository(dio).searchAdventurers('LQ-0000002A');

    expect(searchQuery, 'LQ-0000002A');
  });

  test('친구 목록에도 내 친구 코드를 함께 담는다', () async {
    final dio = _dio((options) {
      if (options.path == '/users/me/friend-code') {
        return {'friendCode': 'LQ-0000002A'};
      }
      return {
        'content': [
          {'userId': 7, 'nickname': '친구', 'level': 3},
        ],
      };
    });

    final list = await FriendRepository(dio).fetchFriends();

    expect(list.myCode, 'LQ-0000002A');
    expect(list.friends.single.nickname, '친구');
  });

  test('전체 레벨 랭킹 경로와 기준을 전달한다', () async {
    String? path;
    String? type;
    final dio = _dio((options) {
      path = options.path;
      type = options.queryParameters['type'] as String?;
      return {'content': <Object>[]};
    });

    await FriendRepository(
      dio,
    ).fetchWeeklyRanking(scope: RankingScope.global, type: RankingType.level);

    expect(path, '/rankings/global');
    expect(type, 'LEVEL');
  });

  test('친구 상세 프로필과 공개 활동을 서버에서 조회한다', () async {
    final dio = _dio((options) {
      expect(options.path, '/friends/7/profile');
      return {
        'userId': 7,
        'nickname': '하늘',
        'representativeTitle': '새벽의 개척자',
        'representativeBadge': '첫걸음',
        'me': {
          'level': 4,
          'totalExp': 320,
          'completedQuestCount': 8,
          'visitedPlaceCount': 2,
        },
        'friend': {
          'level': 6,
          'totalExp': 580,
          'completedQuestCount': 14,
          'visitedPlaceCount': 5,
        },
      };
    });

    final journey = await FriendRepository(dio).fetchJourney(7);

    expect(journey.nickname, '하늘');
    expect(journey.titleLine, '새벽의 개척자');
    expect(journey.badges.single.name, '첫걸음');
    expect(journey.friend.totalExp, 580);
    expect(journey.friend.completedQuestCount, 14);
  });

  test('친구 삭제 API를 호출한다', () async {
    String? method;
    String? path;
    final dio = _dio((options) {
      method = options.method;
      path = options.path;
      return {'deleted': true};
    });

    await FriendRepository(dio).unfriend(7);

    expect(method, 'DELETE');
    expect(path, '/friends/7');
  });
}

Dio _dio(Map<String, dynamic> Function(RequestOptions) responseFor) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: responseFor(options),
        ),
      ),
    ),
  );
  return dio;
}
