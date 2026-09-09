import 'package:google_sign_in/google_sign_in.dart';

abstract interface class IAuthRepository {
  Future<GoogleSignInAccount?> tryRestoreSession();
  Future<GoogleSignInAccount> signIn();
  Future<void> signOut();
}
