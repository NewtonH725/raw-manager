import 'package:flutter_test/flutter_test.dart';
import 'package:raw_manager/services/update_service.dart';

void main() {
  group('UpdateService SemVer Tests', () {
    test('Riconosce correttamente versioni più recenti', () {
      expect(UpdateService.isNewerVersion('v1.2.0', '1.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.1.1', '1.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('V1.1.1+5', '1.1.0'), isTrue);
    });

    test('Rifiuta versioni uguali o inferiori', () {
      expect(UpdateService.isNewerVersion('v1.1.0', '1.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.1.0', '1.1.0+2'), isFalse);
      expect(UpdateService.isNewerVersion('v1.0.9', '1.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('v0.9.9', '1.0.0'), isFalse);
    });
  });
}
