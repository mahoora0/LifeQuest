import 'package:life_quest/shared/data/json_reader.dart';

class AdminQuest {
  const AdminQuest({
    required this.id,
    required this.title,
    required this.grade,
    required this.cadence,
    required this.completionType,
    required this.expReward,
    required this.active,
    this.description,
    this.placeName,
    this.latitude,
    this.longitude,
    this.radiusM,
  });

  final int id;
  final String title;
  final String? description;
  final String grade;
  final String cadence;
  final String completionType;
  final int expReward;
  final bool active;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int? radiusM;

  factory AdminQuest.fromJson(Map<String, dynamic> json) => AdminQuest(
    id: asInt(json['id']) ?? 0,
    title: asString(json['title']) ?? '제목 없음',
    description: asString(json['description']),
    grade: asString(json['grade']) ?? 'NORMAL',
    cadence: asString(json['cadence']) ?? 'DAILY',
    completionType: asString(json['completionType']) ?? 'SELF_REPORT',
    expReward: asInt(json['expReward']) ?? 0,
    active: asBool(json['active'], orElse: true),
    placeName: asString(json['placeName']),
    latitude: asDouble(json['latitude']),
    longitude: asDouble(json['longitude']),
    radiusM: asInt(json['radiusM']),
  );
}

class AdminQuestDraft {
  const AdminQuestDraft({
    required this.title,
    required this.grade,
    required this.cadence,
    required this.completionType,
    required this.expReward,
    required this.active,
    this.description,
    this.placeName,
    this.latitude,
    this.longitude,
    this.radiusM,
  });

  final String title;
  final String? description;
  final String grade;
  final String cadence;
  final String completionType;
  final int expReward;
  final bool active;
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final int? radiusM;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'grade': grade,
    'cadence': cadence,
    'completionType': completionType,
    'expReward': expReward,
    'active': active,
    'placeName': completionType == 'GPS' ? placeName : null,
    'latitude': completionType == 'GPS' ? latitude : null,
    'longitude': completionType == 'GPS' ? longitude : null,
    'radiusM': completionType == 'GPS' ? radiusM : null,
  };
}
