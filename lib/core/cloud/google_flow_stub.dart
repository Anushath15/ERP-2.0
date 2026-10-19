import '../link_launcher.dart';
import 'auth_api.dart';
import 'google_flow.dart';

/// A browser build has no way to wait for itself on this computer: Google sign-in is for the Windows program.
GoogleFlow createGoogleFlow() => _Unsupported();

class _Unsupported implements GoogleFlow {
  @override
  Future<AuthSession> run(AuthApi api, LinkLauncher launcher, {Duration timeout = const Duration(minutes: 3)}) async => throw const AuthFailure(AuthProblem.other);
}
