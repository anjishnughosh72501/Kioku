import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/features/auth/domain/i_auth_repository.dart';
import 'package:flutter_mobile/features/auth/presentation/controllers/auth_controller.dart';

class FakeAuthRepository implements IAuthRepository {
  FakeAuthRepository({this.shouldFail = false});

  final bool shouldFail;
  bool signedOut = false;

  @override
  Future<GoogleSignInAccount?> tryRestoreSession() async {
    return null;
  }

  @override
  Future<GoogleSignInAccount> signIn() async {
    if (shouldFail) throw Exception('OAuth failure');
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  group('AuthController', () {
    test('initializes with unauthenticated state when no prior session exists', () async {
      final fakeRepo = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final authState = container.read(authControllerProvider);
      expect(authState.isSignedIn, isFalse);
      expect(authState.error, isNull);
    });

    test('signIn sets error when repository throws exception', () async {
      final fakeRepo = FakeAuthRepository(shouldFail: true);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signIn();

      final authState = container.read(authControllerProvider);
      expect(authState.isSignedIn, isFalse);
      expect(authState.error, isNotNull);
    });

    test('signOut clears state and calls repository signOut', () async {
      final fakeRepo = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(fakeRepo.signedOut, isTrue);
      expect(container.read(authControllerProvider).isSignedIn, isFalse);
    });
  });
}
