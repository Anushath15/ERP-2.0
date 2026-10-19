import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../link_launcher.dart';
import 'auth_api.dart';
import 'google_flow_stub.dart' if (dart.library.io) 'google_flow_io.dart' as impl;

/// "Continue with Google": opens the normal Google sign-in page in the browser, waits for the browser to come back, and returns the session.
abstract class GoogleFlow {
  Future<AuthSession> run(AuthApi api, LinkLauncher launcher, {Duration timeout});
}

final googleFlowProvider = Provider<GoogleFlow>((ref) => impl.createGoogleFlow());
