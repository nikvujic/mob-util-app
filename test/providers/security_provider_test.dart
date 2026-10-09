import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/providers/security_provider.dart';

void main() {
  const password = 'first password';
  const newPassword = 'second password';

  late SecurityNotifier security;

  setUp(() => security = SecurityNotifier(AppStorage.inMemory()));

  group('rules', () {
    test('need at least 8 characters, not just spaces', () {
      expect(MasterPasswordRules.validate('1234567'), isNotNull);
      expect(MasterPasswordRules.validate('12345678'), isNull);
      expect(MasterPasswordRules.validate('         '), isNotNull);
      expect(MasterPasswordRules.validate('čćšđž€ab'), isNull);
    });

    test('are enforced when setting and changing', () async {
      expect(() => security.setPassword('short'), throwsArgumentError);
      await security.setPassword(password);
      expect(
        () => security.changePassword(password, 'short'),
        throwsArgumentError,
      );
    });
  });

  test('starts without a master password', () {
    expect(security.hasMasterPassword, isFalse);
  });

  test('set, then it can be checked', () async {
    await security.setPassword(password);
    expect(security.hasMasterPassword, isTrue);
    expect(await security.state!.unlock(password), isNotNull);
  });

  test('set twice is refused', () async {
    await security.setPassword(password);
    expect(() => security.setPassword(newPassword), throwsStateError);
  });

  test('change needs the current password', () async {
    await security.setPassword(password);
    final before = security.state;

    await expectLater(
      security.changePassword('wrong one', newPassword),
      throwsA(isA<WrongPasswordException>()),
    );
    expect(identical(security.state, before), isTrue, reason: 'unchanged');

    await security.changePassword(password, newPassword);
    expect(await security.state!.unlock(newPassword), isNotNull);
    expect(await security.state!.unlock(password), isNull);
  });

  test('remove needs the current password', () async {
    await security.setPassword(password);

    await expectLater(
      security.removePassword('wrong one'),
      throwsA(isA<WrongPasswordException>()),
    );
    expect(security.hasMasterPassword, isTrue);

    await security.removePassword(password);
    expect(security.hasMasterPassword, isFalse);
  });

  test('is saved and survives a restart; removal too', () async {
    final dir = Directory.systemTemp.createTempSync('security_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    var storage = await AppStorage.open(directory: dir);
    await SecurityNotifier(storage).setPassword(password);
    await storage.flush();

    final saved = File('${dir.path}/security.json').readAsStringSync();
    expect(saved, isNot(contains(password)), reason: 'never stored');

    storage = await AppStorage.open(directory: dir);
    final reopened = SecurityNotifier(storage);
    expect(reopened.hasMasterPassword, isTrue);
    expect(await reopened.state!.unlock(password), isNotNull);

    await reopened.removePassword(password);
    await storage.flush();
    storage = await AppStorage.open(directory: dir);
    expect(SecurityNotifier(storage).hasMasterPassword, isFalse);
  });

  group('removing runs beforeRemove first', () {
    test('with the data key, while the password is still set', () async {
      late SecurityNotifier notifier;
      DataKey? given;
      var stillSet = false;
      notifier = SecurityNotifier(
        AppStorage.inMemory(),
        beforeRemove: (dataKey) async {
          given = dataKey;
          stillSet = notifier.hasMasterPassword;
        },
      );
      await notifier.setPassword(password);
      final verifier = notifier.state!;
      final expected = await verifier.unwrapDataKey(
        (await verifier.unlock(password))!,
      );

      await notifier.removePassword(password);

      expect(stillSet, isTrue);
      expect(
          await seal([1, 2, 3], given!, context: 'c').then(
            (box) => open(box, expected!, context: 'c'),
          ),
          [1, 2, 3],
          reason: 'the same data key');
      expect(notifier.hasMasterPassword, isFalse);
    });

    test('keeps the password if it fails', () async {
      final notifier = SecurityNotifier(
        AppStorage.inMemory(),
        beforeRemove: (_) async => throw const LockedDataException(),
      );
      await notifier.setPassword(password);

      await expectLater(
        notifier.removePassword(password),
        throwsA(isA<LockedDataException>()),
      );
      expect(notifier.hasMasterPassword, isTrue);
    });

    test('not for a wrong password', () async {
      var called = false;
      final notifier = SecurityNotifier(
        AppStorage.inMemory(),
        beforeRemove: (_) async => called = true,
      );
      await notifier.setPassword(password);
      await expectLater(
        notifier.removePassword('wrong password'),
        throwsA(isA<WrongPasswordException>()),
      );
      expect(called, isFalse);
    });
  });
}
