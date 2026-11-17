import 'package:farzandim_child/features/screen_time/domain/screen_time_error_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard mode invalidAccountType gets its own message', () {
    expect(
      screenTimeErrorKey('invalidAccountType'),
      'screenTime.err.invalidAccountTypeStandard',
    );
  });

  test('strict mode invalidAccountType keeps the Family Sharing message', () {
    expect(
      screenTimeErrorKey('invalidAccountType', isStrictMode: true),
      'screenTime.err.invalidAccountType',
    );
  });

  test('other known codes map the same in both modes', () {
    for (final isStrict in [false, true]) {
      expect(
        screenTimeErrorKey(
          'authenticationMethodUnavailable',
          isStrictMode: isStrict,
        ),
        'screenTime.err.authenticationMethodUnavailable',
      );
    }
  });

  test('unknown codes fall back to the generic message', () {
    expect(screenTimeErrorKey('notAuthorized'), 'screenTime.err.generic');
    expect(
      screenTimeErrorKey('busy', isStrictMode: true),
      'screenTime.err.generic',
    );
  });
}
