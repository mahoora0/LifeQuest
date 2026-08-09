import 'package:dio/dio.dart';
import 'package:life_quest/core/network/api_exception.dart';
import 'package:life_quest/features/user/data/user_dto.dart';
import 'package:life_quest/shared/data/json_reader.dart';

class UserRepository {
  const UserRepository(this._dio);

  final Dio _dio;

  Future<UserProfile> fetchMe() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me');
    return UserProfile.fromJson(response.data);
  });

  Future<UserProfile> updateProfile({required String nickname}) =>
      _guard(() async {
        final response = await _dio.patch<dynamic>(
          '/users/me',
          data: {'nickname': nickname},
        );
        return UserProfile.fromJson(response.data);
      });

  Future<UserProfile> uploadProfileImage(String path) => _guard(() async {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    final response = await _dio.post<dynamic>(
      '/users/me/profile-image',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: fileName),
      }),
    );
    return UserProfile.fromJson(response.data);
  });

  Future<UserProfile> deleteProfileImage() => _guard(() async {
    final response = await _dio.delete<dynamic>('/users/me/profile-image');
    return UserProfile.fromJson(response.data);
  });

  Future<List<AvatarCharacter>> fetchCharacters() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/characters');
    return asMapList(response.data).map(AvatarCharacter.fromJson).toList();
  });

  Future<UserProfile> selectCharacter(int characterId) => _guard(() async {
    final response = await _dio.patch<dynamic>(
      '/users/me/character',
      data: {'characterId': characterId},
    );
    return UserProfile.fromJson(response.data);
  });

  Future<AccessoryCollection> fetchAccessories() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/accessories');
    return AccessoryCollection.fromJson(response.data);
  });

  Future<UserProfile> selectAccessory(int? accessoryId) => _guard(() async {
    final response = await _dio.patch<dynamic>(
      '/users/me/accessory',
      data: {'accessoryId': accessoryId},
    );
    return UserProfile.fromJson(response.data);
  });

  Future<LevelStatus> fetchLevel() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/level');
    return LevelStatus.fromJson(response.data);
  });

  Future<TitleCollection> fetchTitles() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/titles');
    return TitleCollection.fromJson(response.data);
  });

  /// 대표 칭호 설정. 해제는 `titleId = null`.
  Future<void> updateRepresentativeTitle(int? titleId) => _guard(() async {
    await _dio.patch<dynamic>('/users/me/title', data: {'titleId': titleId});
  });

  Future<BadgeCollection> fetchBadges() => _guard(() async {
    final response = await _dio.get<dynamic>('/users/me/badges');
    return BadgeCollection.fromJson(response.data);
  });

  Future<void> updateRepresentativeBadge(int? badgeId) => _guard(() async {
    await _dio.patch<dynamic>('/users/me/badge', data: {'badgeId': badgeId});
  });

  Future<RewardHistory> fetchRewards() => _guard(() async {
    final response = await _dio.get<dynamic>(
      '/users/me/rewards',
      queryParameters: const {'page': 0, 'size': 20},
    );
    return RewardHistory.fromJson(response.data);
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
