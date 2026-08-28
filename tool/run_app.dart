import 'dart:convert';
import 'dart:io';

const expectedFlutterVersion = '3.44.8';

Future<void> main(List<String> arguments) async {
  try {
    final options = _Options.parse(arguments);
    if (options.showHelp) {
      stdout.write(_usage);
      return;
    }

    final repositoryRoot = File.fromUri(Platform.script).parent.parent;
    final appDirectory = Directory(_join(repositoryRoot.path, 'app'));
    final environmentFile = File(_join(repositoryRoot.path, '.env'));
    final flutter = _findFlutter(repositoryRoot);

    await _verifyFlutterVersion(flutter);

    final devices = await _loadDevices(flutter);
    if (options.listDevices) {
      _printDevices(devices);
      return;
    }

    final environment = _readEnvironment(environmentFile);
    final device = _selectDevice(
      devices,
      options,
      savedDeviceId: environment['FLUTTER_DEVICE_ID']?.trim(),
    );
    final googleClientId = environment['GOOGLE_CLIENT_ID']?.trim() ?? '';
    if (googleClientId.isEmpty) {
      throw const _RunnerException(
        ".env의 GOOGLE_CLIENT_ID에 Google 웹 OAuth 클라이언트 ID를 입력하세요.",
      );
    }

    // 지도 키는 없어도 앱이 뜬다 — 지도 자리에 대체 화면이 그려진다. 실행을 막지 않고
    // 알리기만 하는 이유는, 지도를 쓰지 않는 화면을 확인하려는 실행까지 함께 막히기 때문이다.
    final naverMapClientId = environment['NAVER_MAP_CLIENT_ID']?.trim() ?? '';
    if (naverMapClientId.isEmpty) {
      stdout.writeln(
        '알림: .env의 NAVER_MAP_CLIENT_ID가 비어 있어 지도가 대체 화면으로 표시됩니다.',
      );
    }

    final useLan = options.useLan || device.requiresLan;
    final apiBaseUrl =
        options.apiBaseUrl ??
        (useLan
            ? environment['FLUTTER_API_BASE_URL']?.trim()
            : device.defaultApiBaseUrl);

    if (apiBaseUrl == null || apiBaseUrl.isEmpty) {
      throw _RunnerException(
        '${device.name} 실행에는 .env의 FLUTTER_API_BASE_URL 또는 '
        '--api-base-url이 필요합니다.',
      );
    }

    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
      throw _RunnerException('API 주소 형식이 올바르지 않습니다: $apiBaseUrl');
    }

    if (device.shouldReverse(useLan: useLan, apiUri: apiUri)) {
      await _configureAdbReverse(device, apiUri.port);
    }

    final flutterArguments = <String>[
      'run',
      '-d',
      device.id,
      '--dart-define=API_BASE_URL=$apiBaseUrl',
      '--dart-define=GOOGLE_SERVER_CLIENT_ID=$googleClientId',
      '--dart-define=NAVER_MAP_CLIENT_ID=$naverMapClientId',
      ...options.flutterArguments,
    ];

    stdout.writeln('Flutter ${device.name} (${device.id}) → $apiBaseUrl');
    final process = await Process.start(
      flutter,
      flutterArguments,
      workingDirectory: appDirectory.path,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } on _RunnerException catch (error) {
    stderr.writeln('오류: ${error.message}');
    exitCode = 64;
  } on ProcessException catch (error) {
    stderr.writeln('오류: ${error.message}');
    exitCode = 69;
  }
}

String _findFlutter(Directory repositoryRoot) {
  final executable = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final fvmFlutter = File(
    _join(
      repositoryRoot.path,
      '.fvm',
      'flutter_sdk',
      'bin${Platform.pathSeparator}$executable',
    ),
  );
  return fvmFlutter.existsSync() ? fvmFlutter.path : 'flutter';
}

Future<void> _verifyFlutterVersion(String flutter) async {
  final result = await Process.run(flutter, const [
    '--version',
    '--machine',
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    throw const _RunnerException(
      'flutter를 실행할 수 없습니다. Flutter SDK를 PATH에 추가하세요.',
    );
  }

  try {
    final versionInfo =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final installedVersion = versionInfo['frameworkVersion'] as String?;
    if (installedVersion != expectedFlutterVersion) {
      throw _RunnerException(
        'Flutter $expectedFlutterVersion이 필요하지만 '
        '${installedVersion ?? "알 수 없는 버전"}이 선택되어 있습니다. '
        'PATH 또는 FVM 설정을 확인하세요.',
      );
    }
  } on FormatException {
    throw const _RunnerException('flutter 버전 정보를 읽을 수 없습니다.');
  }
}

Future<List<_Device>> _loadDevices(String flutter) async {
  final result = await Process.run(flutter, const [
    'devices',
    '--machine',
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    throw _RunnerException(
      '기기 목록을 읽지 못했습니다.\n${(result.stderr as String).trim()}',
    );
  }

  try {
    final rawDevices = jsonDecode(result.stdout as String) as List<dynamic>;
    return rawDevices
        .map((value) => _Device.fromJson(value as Map<String, dynamic>))
        .where((device) => device.isSupportedMobile)
        .toList();
  } on FormatException {
    throw const _RunnerException('Flutter 기기 목록 형식이 올바르지 않습니다.');
  }
}

_Device _selectDevice(
  List<_Device> devices,
  _Options options, {
  String? savedDeviceId,
}) {
  var candidates = devices;
  final deviceId = options.deviceId ?? savedDeviceId;

  if (deviceId != null && deviceId.isNotEmpty) {
    candidates = devices.where((device) => device.id == deviceId).toList();
  }

  switch (options.target) {
    case _Target.auto:
      break;
    case _Target.emulator:
      candidates = candidates
          .where((device) => device.isAndroid && device.isEmulator)
          .toList();
    case _Target.usb:
      candidates = candidates
          .where((device) => device.isAndroid && !device.isEmulator)
          .toList();
    case _Target.ios:
      candidates = candidates.where((device) => device.isIos).toList();
  }

  if (candidates.length == 1) {
    return candidates.single;
  }
  if (candidates.isEmpty) {
    if (deviceId != null && deviceId.isNotEmpty) {
      throw _RunnerException(
        '지정된 기기 "$deviceId"를 찾지 못했습니다. '
        '--list-devices로 현재 ID를 확인하세요.',
      );
    }
    throw const _RunnerException(
      '실행 가능한 Android/iOS 기기를 찾지 못했습니다. '
      '기기를 연결하거나 에뮬레이터/시뮬레이터를 먼저 실행하세요.',
    );
  }

  final choices = candidates
      .map((device) => '  ${device.id}  ${device.name}')
      .join('\n');
  throw _RunnerException('실행 가능한 기기가 여러 개입니다. --device로 하나를 지정하세요.\n$choices');
}

Map<String, String> _readEnvironment(File file) {
  if (!file.existsSync()) {
    throw const _RunnerException(
      "루트 .env 파일이 없습니다. '.env.example'을 '.env'로 복사하세요.",
    );
  }

  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }

    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2) {
      final isDoubleQuoted = value.startsWith('"') && value.endsWith('"');
      final isSingleQuoted = value.startsWith("'") && value.endsWith("'");
      if (isDoubleQuoted || isSingleQuoted) {
        value = value.substring(1, value.length - 1);
      }
    }
    values[key] = value;
  }
  return values;
}

Future<void> _configureAdbReverse(_Device device, int port) async {
  final adb = _findAdb();
  if (adb == null) {
    throw const _RunnerException(
      'adb를 찾을 수 없습니다. Android SDK Platform-Tools를 설치하고 '
      'PATH, ANDROID_HOME 또는 ANDROID_SDK_ROOT를 설정하세요.',
    );
  }

  final result = await Process.run(adb, [
    '-s',
    device.id,
    'reverse',
    'tcp:$port',
    'tcp:$port',
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    throw _RunnerException(
      'adb reverse 설정에 실패했습니다. USB 디버깅 허용 상태를 확인하세요.\n'
      '${(result.stderr as String).trim()}',
    );
  }
}

String? _findAdb() {
  final executable = Platform.isWindows ? 'adb.exe' : 'adb';
  final pathDirectories = (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  );
  final sdkRoots = <String?>[
    Platform.environment['ANDROID_HOME'],
    Platform.environment['ANDROID_SDK_ROOT'],
    if (Platform.isWindows && Platform.environment['LOCALAPPDATA'] != null)
      _join(Platform.environment['LOCALAPPDATA']!, 'Android', 'Sdk'),
    if (Platform.isMacOS && Platform.environment['HOME'] != null)
      _join(Platform.environment['HOME']!, 'Library', 'Android', 'sdk'),
    if (Platform.isLinux && Platform.environment['HOME'] != null)
      _join(Platform.environment['HOME']!, 'Android', 'Sdk'),
  ];

  for (final directory in pathDirectories) {
    if (directory.isEmpty) {
      continue;
    }
    final candidate = File(_join(directory, executable));
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  for (final root in sdkRoots.whereType<String>()) {
    final candidate = File(_join(root, 'platform-tools', executable));
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }
  return null;
}

void _printDevices(List<_Device> devices) {
  if (devices.isEmpty) {
    stdout.writeln('실행 가능한 Android/iOS 기기가 없습니다.');
    return;
  }
  for (final device in devices) {
    stdout.writeln('${device.id}\t${device.name}\t${device.targetPlatform}');
  }
}

String _join(String first, String second, [String? third, String? fourth]) {
  final separator = Platform.pathSeparator;
  return [first, second, third, fourth]
      .whereType<String>()
      .map((part) => part.replaceAll(RegExp(r'[/\\]+$'), ''))
      .join(separator);
}

enum _Target { auto, emulator, usb, ios }

final class _Options {
  const _Options({
    required this.target,
    required this.useLan,
    required this.showHelp,
    required this.listDevices,
    required this.flutterArguments,
    this.apiBaseUrl,
    this.deviceId,
  });

  factory _Options.parse(List<String> arguments) {
    var target = _Target.auto;
    var useLan = false;
    var showHelp = false;
    var listDevices = false;
    String? apiBaseUrl;
    String? deviceId;
    final flutterArguments = <String>[];

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--') {
        flutterArguments.addAll(arguments.skip(index + 1));
        break;
      }
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        case '--list-devices':
          listDevices = true;
        case '--lan':
          useLan = true;
        case '--device':
        case '-d':
          deviceId = _nextValue(arguments, ++index, argument);
        case '--api-base-url':
          apiBaseUrl = _nextValue(arguments, ++index, argument);
        case '--target':
          final value = _nextValue(arguments, ++index, argument);
          target = switch (value) {
            'auto' => _Target.auto,
            'emulator' => _Target.emulator,
            'usb' => _Target.usb,
            'ios' => _Target.ios,
            _ => throw _RunnerException(
              '--target은 auto, emulator, usb, ios 중 하나여야 합니다.',
            ),
          };
        default:
          throw _RunnerException('알 수 없는 옵션입니다: $argument\n\n$_usage');
      }
    }

    return _Options(
      target: target,
      useLan: useLan,
      showHelp: showHelp,
      listDevices: listDevices,
      apiBaseUrl: apiBaseUrl,
      deviceId: deviceId,
      flutterArguments: flutterArguments,
    );
  }

  final _Target target;
  final bool useLan;
  final bool showHelp;
  final bool listDevices;
  final String? apiBaseUrl;
  final String? deviceId;
  final List<String> flutterArguments;
}

String _nextValue(List<String> arguments, int index, String option) {
  if (index >= arguments.length || arguments[index] == '--') {
    throw _RunnerException('$option 뒤에 값을 입력하세요.');
  }
  return arguments[index];
}

final class _Device {
  const _Device({
    required this.id,
    required this.name,
    required this.targetPlatform,
    required this.isEmulator,
    required this.isSupported,
  });

  factory _Device.fromJson(Map<String, dynamic> json) => _Device(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unknown device',
    targetPlatform: json['targetPlatform'] as String? ?? '',
    isEmulator: json['emulator'] as bool? ?? false,
    isSupported: json['isSupported'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String targetPlatform;
  final bool isEmulator;
  final bool isSupported;

  bool get isAndroid => targetPlatform.startsWith('android');
  bool get isIos => targetPlatform.startsWith('ios');
  bool get isSupportedMobile => isSupported && (isAndroid || isIos);

  bool get requiresLan => isIos && !isEmulator;

  String? get defaultApiBaseUrl {
    if (isAndroid && isEmulator) {
      return 'http://10.0.2.2:8080/api';
    }
    if (isIos && isEmulator) {
      return 'http://127.0.0.1:8080/api';
    }
    if (isAndroid) {
      return 'http://127.0.0.1:8080/api';
    }
    return null;
  }

  bool shouldReverse({required bool useLan, required Uri apiUri}) {
    if (!isAndroid || isEmulator || useLan) {
      return false;
    }
    return apiUri.host == '127.0.0.1' || apiUri.host == 'localhost';
  }
}

final class _RunnerException implements Exception {
  const _RunnerException(this.message);

  final String message;
}

const _usage = '''
LifeQuest Flutter 실행기

사용법:
  dart run tool/run_app.dart [옵션] [-- Flutter 옵션]

연결된 모바일 기기가 하나면 자동으로 선택합니다.
여러 기기를 쓰는 PC는 .env의 FLUTTER_DEVICE_ID로 기본 기기를 저장할 수 있습니다.

옵션:
  --device, -d <id>        실행할 Flutter 기기 ID
  --target <종류>          auto, emulator, usb, ios (기본: auto)
  --lan                    USB 포워딩 대신 .env의 LAN 주소 사용
  --api-base-url <url>     이번 실행에서 사용할 API 주소
  --list-devices           실행 가능한 Android/iOS 기기 표시
  --help, -h               도움말 표시

예:
  dart run tool/run_app.dart
  dart run tool/run_app.dart --target emulator
  dart run tool/run_app.dart --target usb
  dart run tool/run_app.dart --target ios
  dart run tool/run_app.dart --lan
  dart run tool/run_app.dart -- --profile
''';
