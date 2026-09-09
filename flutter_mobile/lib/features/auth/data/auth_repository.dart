import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../domain/i_auth_repository.dart';

class AuthRepository implements IAuthRepository {
  static const driveScope = drive.DriveApi.driveFileScope;

  static const webClientId =
      '259865154402-h2m8hdminqd8td2hgjk9uhp3djl6caci.apps.googleusercontent.com';

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId,
    );
    _initialized = true;
  }

  @override
  Future<GoogleSignInAccount?> tryRestoreSession() async {
    await _ensureInitialized();
    return GoogleSignIn.instance.attemptLightweightAuthentication();
  }

  @override
  Future<GoogleSignInAccount> signIn() async {
    await _ensureInitialized();
    return GoogleSignIn.instance.authenticate(
      scopeHint: [driveScope],
    );
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}
