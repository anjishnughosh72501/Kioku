/// Auth Controller — Google Sign-In backed auth state.
/// The signed-in user's own Google account is the identity; Drive access is
/// handled by AppDrive using that account's token.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/features/auth/domain/i_auth_repository.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
      (ref) => AuthController(ref.watch(authRepositoryProvider)),
    );

@immutable
class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isSignedIn = false,
    this.isGuest = false,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });

  final bool isLoading;
  final bool isSignedIn;
  final bool isGuest;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;

  bool get isAuthenticated => isSignedIn || isGuest;

  AuthState copyWith({
    bool? isLoading,
    bool? isSignedIn,
    bool? isGuest,
    String? email,
    String? displayName,
    String? photoUrl,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      isGuest: isGuest ?? this.isGuest,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authRepo) : super(const AuthState(isLoading: true)) {
    _bootstrap();
  }

  final IAuthRepository _authRepo;

  /// Restore a previous Google session with minimal UI.
  /// After first startup, if no Google session is present, automatically enter
  /// guest/local mode so the app directly opens to feed without storage prompt.
  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasStartedBefore = prefs.getBool('first_startup_completed') ?? false;

      final account = await _authRepo.tryRestoreSession();
      if (!mounted) return;
      if (account == null) {
        if (hasStartedBefore) {
          state = state.copyWith(isGuest: true, isLoading: false, error: null);
          return;
        }
        state = state.copyWith(isLoading: false);
        return;
      }
      await _finishSignIn(account);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not restore previous session: $e',
      );
    }
  }

  /// Enter local/offline mode without signing into Google.
  void continueAsGuest() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('first_startup_completed', true);
    });
    state = state.copyWith(isGuest: true, isLoading: false, error: null);
  }

  /// Interactive Google Sign-In (Drive scope pre-authorized).
  Future<void> signIn() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final account = await _authRepo.signIn();
      await _finishSignIn(account);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Sign-in was dismissed. Make sure a Google account is added in your device/emulator Settings.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error:
              'Sign-in failed (${e.code.name}): ${e.description ?? 'Please verify your Google Cloud OAuth setup'}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign-in error: $e',
      );
    }
  }

  Future<void> _finishSignIn(GoogleSignInAccount account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_startup_completed', true);
      AppDrive.instance.bind(account);
      // Pre-authorize the Drive scope so the first Drive call works instantly.
      await AppDrive.instance.accessToken();
      if (!mounted) return;
      state = AuthState(
        isSignedIn: true,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      AppDrive.instance.clear();
      if (!mounted) return;
      state = AuthState(
        isLoading: false,
        error: 'Connected to Google but could not reach Drive: $e',
      );
    }
  }

  /// Sign out of Google and drop cached Drive data.
  Future<void> signOut() async {
    AppDrive.instance.clear();
    try {
      await _authRepo.signOut();
    } catch (_) {
      // Even if the platform call fails, we clear local state below.
    }
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(error: null);
}