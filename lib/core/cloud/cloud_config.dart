import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the shop's cloud copy (Supabase) is. Both values are PUBLIC by design (the project address and the "publishable" key;
/// the data itself is protected by row-level security). They are not stored in the code: the build passes them in with
/// `flutter build windows --dart-define-from-file=supabase/config.local.json`.
/// Without them the program works exactly as before, on this computer only, and the sign-in screen is the old preview.
class CloudConfig {
  const CloudConfig({required this.url, required this.key});

  final String url, key;

  bool get configured => url.startsWith('https://') && key.isNotEmpty;

  /// The address without a trailing slash.
  String get base => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static const fromBuild = CloudConfig(url: String.fromEnvironment('url'), key: String.fromEnvironment('publishableKey'));
}

final cloudConfigProvider = Provider<CloudConfig>((ref) => CloudConfig.fromBuild);
