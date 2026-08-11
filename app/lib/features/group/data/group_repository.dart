import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/group/data/group_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';

class GroupRepository {
  const GroupRepository(this._dio);

  static const _pageSize = 50;

  final Dio _dio;
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<List<GroupSummary>> myGroups() => _guard(() async {
    final r = await _dio.get<dynamic>('/groups/me');
    return asMapList(r.data).map(GroupSummary.fromJson).toList();
  });
  Future<List<GroupSummary>> search(String query) => _guard(() async {
    final r = await _dio.get<dynamic>(
      '/groups/search',
      queryParameters: {'query': query, 'page': 0, 'size': 50},
    );
    return asMapList(
      asMap(r.data)['content'],
    ).map(GroupSummary.fromJson).toList();
  });
  Future<List<GroupUserLookup>> searchUsers(String nickname) =>
      _guard(() async {
        final r = await _dio.get<dynamic>(
          '/users/search',
          queryParameters: {'nickname': nickname, 'page': 0, 'size': 50},
        );
        return asMapList(
          asMap(r.data)['content'],
        ).map(GroupUserLookup.fromJson).toList();
      });
  Future<GroupDetail> detail(int id) => _guard(
    () async =>
        GroupDetail.fromJson((await _dio.get<dynamic>('/groups/$id')).data),
  );
  Future<GroupDetail> create({
    required String name,
    required String description,
    required GroupVisibility visibility,
    required int maxMembers,
  }) => _guard(
    () async => GroupDetail.fromJson(
      (await _dio.post<dynamic>(
        '/groups',
        data: {
          'name': name,
          'description': description,
          'visibility': visibility == GroupVisibility.public
              ? 'PUBLIC'
              : 'PRIVATE',
          'maxMembers': maxMembers,
        },
      )).data,
    ),
  );
  Future<GroupDetail> update(
    int id, {
    required String name,
    required String description,
    required GroupVisibility visibility,
    required int maxMembers,
  }) => _guard(
    () async => GroupDetail.fromJson(
      (await _dio.patch<dynamic>(
        '/groups/$id',
        data: {
          'name': name,
          'description': description,
          'visibility': visibility == GroupVisibility.public
              ? 'PUBLIC'
              : 'PRIVATE',
          'maxMembers': maxMembers,
        },
      )).data,
    ),
  );
  Future<void> archive(int id) => _guard(() async {
    await _dio.delete<dynamic>('/groups/$id');
  });
  Future<void> deletePermanently(int id) => _guard(() async {
    await _dio.delete<dynamic>('/groups/$id/permanent');
  });
  Future<void> join(int id) => _guard(() async {
    await _dio.post<dynamic>('/groups/$id/join-requests');
  });
  Future<void> invite(int id, int userId) => _guard(() async {
    await _dio.post<dynamic>(
      '/groups/$id/invitations',
      data: {'userId': userId},
    );
  });
  Future<List<GroupMember>> invitations() => _members('/groups/invitations');
  Future<void> acceptInvitation(int memberId) => _guard(() async {
    await _dio.post<dynamic>('/groups/invitations/$memberId/accept');
  });
  Future<void> declineInvitation(int memberId) => _guard(() async {
    await _dio.post<dynamic>('/groups/invitations/$memberId/decline');
  });
  Future<List<GroupMember>> members(int id) => _members('/groups/$id/members');
  Future<List<GroupMember>> joinRequests(int id) =>
      _members('/groups/$id/join-requests');
  Future<void> approveJoin(int id, int memberId) => _guard(() async {
    await _dio.post<dynamic>('/groups/$id/join-requests/$memberId/approve');
  });
  Future<void> rejectJoin(int id, int memberId) => _guard(() async {
    await _dio.post<dynamic>('/groups/$id/join-requests/$memberId/reject');
  });
  Future<void> leave(int id) => _guard(() async {
    await _dio.delete<dynamic>('/groups/$id/members/me');
  });
  Future<void> remove(int id, int userId) => _guard(() async {
    await _dio.delete<dynamic>('/groups/$id/members/$userId');
  });
  Future<void> transfer(int id, int userId) => _guard(() async {
    await _dio.post<dynamic>(
      '/groups/$id/owner-transfer',
      data: {'newOwnerUserId': userId},
    );
  });
  Future<List<GroupMember>> _members(String path) => _guard(() async {
    final content = await _allPages(path);
    return content.map(GroupMember.fromJson).toList();
  });
  Future<GroupMessagePage> messages(int id, {int? beforeId, int? afterId}) =>
      _guard(() async {
        final query = <String, dynamic>{'size': 50};
        if (beforeId != null) {
          query['beforeId'] = beforeId;
        }
        if (afterId != null) {
          query['afterId'] = afterId;
        }
        return GroupMessagePage.fromJson(
          (await _dio.get<dynamic>(
            '/groups/$id/messages',
            queryParameters: query,
          )).data,
        );
      });
  Future<GroupMessage> sendMessage(int id, String content) => _guard(
    () async => GroupMessage.fromJson(
      asMap(
        (await _dio.post<dynamic>(
          '/groups/$id/messages',
          data: {'content': content},
        )).data,
      ),
    ),
  );
  Future<List<GroupQuest>> quests(int id, {required bool upcoming}) =>
      _guard(() async {
        final content = await _allPages(
          '/groups/$id/quests',
          queryParameters: {'scope': upcoming ? 'UPCOMING' : 'PAST'},
        );
        return content.map(GroupQuest.fromJson).toList();
      });
  Future<List<GroupQuest>> myQuests({required bool upcoming}) =>
      _guard(() async {
        final content = await _allPages(
          '/group-quests/me',
          queryParameters: {'scope': upcoming ? 'UPCOMING' : 'PAST'},
        );
        return content.map(GroupQuest.fromJson).toList();
      });

  /// 화면이 페이지 UI를 제공하지 않는 그룹 목록은 서버의 모든 페이지를 모은다.
  ///
  /// 첫 응답에서 전체 페이지 수를 확인한 뒤 나머지를 병렬로 요청한다. [Future.wait]는
  /// 입력 순서대로 결과를 돌려주므로 서버 페이지 순서도 그대로 유지된다.
  Future<List<Map<String, dynamic>>> _allPages(
    String path, {
    Map<String, dynamic> queryParameters = const {},
  }) async {
    Future<Map<String, dynamic>> fetchPage(int page) async {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: {...queryParameters, 'page': page, 'size': _pageSize},
      );
      return asMap(response.data);
    }

    final first = await fetchPage(0);
    final totalPages = asInt(first['totalPages']) ?? 1;
    final result = <Map<String, dynamic>>[...asMapList(first['content'])];
    if (totalPages <= 1) return result;

    final remaining = await Future.wait([
      for (var page = 1; page < totalPages; page++) fetchPage(page),
    ]);
    for (final page in remaining) {
      result.addAll(asMapList(page['content']));
    }
    return result;
  }

  Future<GroupQuest> quest(int id, int questId) => _guard(
    () async => GroupQuest.fromJson(
      asMap((await _dio.get<dynamic>('/groups/$id/quests/$questId')).data),
    ),
  );
  Future<GroupQuest> saveQuest(
    int id, {
    int? questId,
    required String title,
    required String description,
    required String placeName,
    required DateTime scheduledAt,
    int? maxParticipants,
  }) => _guard(() async {
    // 정원을 비워 보내면(null) 서버가 "정원 없음"으로 저장한다.
    final data = {
      'title': title,
      'description': description,
      'placeName': placeName,
      'scheduledAt': scheduledAt.toIso8601String(),
      'maxParticipants': maxParticipants,
    };
    final r = questId == null
        ? await _dio.post<dynamic>('/groups/$id/quests', data: data)
        : await _dio.patch<dynamic>('/groups/$id/quests/$questId', data: data);
    return GroupQuest.fromJson(asMap(r.data));
  });
  Future<void> cancelQuest(int id, int questId) => _guard(() async {
    await _dio.delete<dynamic>('/groups/$id/quests/$questId');
  });
  Future<void> deleteQuestPermanently(int id, int questId) => _guard(() async {
    await _dio.delete<dynamic>('/groups/$id/quests/$questId/permanent');
  });
  Future<GroupQuest> applyToQuest(int id, int questId) => _guard(() async {
    final r = await _dio.post<dynamic>(
      '/groups/$id/quests/$questId/participation',
    );
    return GroupQuest.fromJson(asMap(r.data));
  });
  Future<GroupQuest> withdrawFromQuest(int id, int questId) => _guard(() async {
    final r = await _dio.delete<dynamic>(
      '/groups/$id/quests/$questId/participation',
    );
    return GroupQuest.fromJson(asMap(r.data));
  });
  Future<GroupQuest> completeGroupQuest(int id, int questId) =>
      _guard(() async {
        final r = await _dio.post<dynamic>(
          '/groups/$id/quests/$questId/complete',
        );
        return GroupQuest.fromJson(asMap(r.data));
      });
}
