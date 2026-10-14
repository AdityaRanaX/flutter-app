import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/services/auth_service.dart';

void main() {
  group('AuthService Unit Tests', () {
    test('AuthException creates formatted exception string', () {
      const exception = AuthException(
        'Incorrect email or password. Please try again.',
        code: 'wrong-password',
      );
      expect(
        exception.message,
        'Incorrect email or password. Please try again.',
      );
      expect(exception.code, 'wrong-password');
      expect(
        exception.toString(),
        'Incorrect email or password. Please try again.',
      );
    });
  });
}
