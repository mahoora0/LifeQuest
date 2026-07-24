/// 서버 응답 필드를 방어적으로 읽는 헬퍼.
///
/// 백엔드 구현이 진행 중이라 일부 필드는 이름·타입이 확정되지 않았다.
/// 여기서 타입을 넓게 받아 화면이 죽지 않도록 한다.
library;

int? asInt(Object? value) => switch (value) {
  int v => v,
  double v => v.round(),
  String v => int.tryParse(v),
  _ => null,
};

double? asDouble(Object? value) => switch (value) {
  double v => v,
  num v => v.toDouble(),
  String v => double.tryParse(v),
  _ => null,
};

String? asString(Object? value) => switch (value) {
  String v => v,
  null => null,
  _ => value.toString(),
};

bool asBool(Object? value, {bool orElse = false}) => switch (value) {
  bool v => v,
  num v => v != 0,
  String v => v.toLowerCase() == 'true',
  _ => orElse,
};

Map<String, dynamic> asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> asMapList(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const <Map<String, dynamic>>[];

/// 여러 후보 키 중 처음으로 값이 있는 것을 반환한다.
Object? pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}
