import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var channelCalls = 0;

  void mockIsTv(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(PlatformDetector.channel, (call) {
      channelCalls++;
      return handler(call);
    });
  }

  setUp(() {
    channelCalls = 0;
    PlatformDetector.isAndroidPlatform = () => true;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(PlatformDetector.channel, null);
    PlatformDetector.isAndroidPlatform = PlatformDetector.defaultIsAndroid;
  });

  test('Android TV según el canal nativo', () async {
    mockIsTv((call) async => call.method == 'isTv' ? true : null);
    await PlatformDetector.init();
    expect(PlatformDetector.isAndroidTV, isTrue);
    expect(PlatformDetector.isMobile, isFalse);
  });

  test('un Android que no es TV usa la interfaz móvil', () async {
    mockIsTv((call) async => false);
    await PlatformDetector.init();
    expect(PlatformDetector.isAndroidTV, isFalse);
    expect(PlatformDetector.isMobile, isTrue);
  });

  test('si el canal falla se asume que no es TV', () async {
    mockIsTv((call) async => throw PlatformException(code: 'boom'));
    await PlatformDetector.init();
    expect(PlatformDetector.isAndroidTV, isFalse);
  });

  test('fuera de Android no se consulta el canal', () async {
    PlatformDetector.isAndroidPlatform = () => false;
    mockIsTv((call) async => true);
    await PlatformDetector.init();
    expect(PlatformDetector.isAndroidTV, isFalse);
    expect(channelCalls, 0);
  });

  test('init vuelve a calcular el estado desde cero', () async {
    mockIsTv((call) async => true);
    await PlatformDetector.init();
    expect(PlatformDetector.isAndroidTV, isTrue);
    mockIsTv((call) async => false);
    await PlatformDetector.init();
    expect(PlatformDetector.isAndroidTV, isFalse);
  });
}
