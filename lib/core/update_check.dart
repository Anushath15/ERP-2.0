/// "Is there a newer program?" The releases are published on the program's GitHub page; this asks GitHub for the latest one (a small, public
/// read: no sign-in, nothing about the shop is sent) and compares its version with this program's. With no internet it quietly says nothing.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'app_info.dart';

const updateRepo = 'Anushath15/ERP-2.0';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.notes, required this.pageUrl, this.downloadUrl = ''});
  final String version, notes, pageUrl;

  /// The installer itself (the Setup .exe attached to the release), or empty when the release has none.
  final String downloadUrl;
}

/// Compares two versions like 2.1.0, 2.0.0-proto.3 or v2.1: by their numbers; when the numbers are equal, a plain version is newer than a
/// "-something" pre-release of it. True when [a] is newer than [b].
bool isNewerVersion(String a, String b) {
  (List<int>, bool) parts(String v) {
    final t = v.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');
    final main = t.split(RegExp(r'[-+]')).first;
    final nums = [for (final p in main.split('.')) int.tryParse(p) ?? 0];
    while (nums.length < 3) {
      nums.add(0);
    }
    return (nums, t.contains('-'));
  }

  final (x, xPre) = parts(a);
  final (y, yPre) = parts(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] > y[i];
  }
  return !xPre && yPre;
}

/// Reads GitHub's answer for the latest release. Null when there is no usable release.
UpdateInfo? parseRelease(String body) {
  try {
    final j = jsonDecode(body);
    if (j is! Map || j['draft'] == true || j['prerelease'] == true) return null;
    final tag = '${j['tag_name'] ?? ''}'.trim();
    final page = '${j['html_url'] ?? ''}';
    if (tag.isEmpty || !page.startsWith('https://github.com/')) return null;
    var download = '';
    final assets = j['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map && '${a['name']}'.toLowerCase().endsWith('.exe')) {
          final u = '${a['browser_download_url'] ?? ''}';
          if (u.startsWith('https://github.com/')) download = u; // SECURITY: only GitHub's own download address is ever opened
        }
      }
    }
    final notes = '${j['body'] ?? ''}'.trim();
    return UpdateInfo(version: tag.replaceFirst(RegExp(r'^[vV]'), ''), notes: notes.length > 600 ? '${notes.substring(0, 600)}...' : notes, pageUrl: page, downloadUrl: download);
  } catch (_) {
    return null;
  }
}

/// Asks GitHub; null when offline, when GitHub says no, or when the latest release is not newer than [current].
Future<UpdateInfo?> checkForUpdate({http.Client? client, String current = appVersionLabel}) async {
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse('https://api.github.com/repos/$updateRepo/releases/latest'), headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'ASK-ERP-2'}).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200 || r.bodyBytes.length > 512 * 1024) return null;
    final info = parseRelease(utf8.decode(r.bodyBytes, allowMalformed: true));
    if (info == null || !isNewerVersion(info.version, current)) return null;
    return info;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// The newer program, when there is one; checked once when the program starts (a little after, so starting stays quick) and when asked.
class UpdateNotifier extends Notifier<UpdateInfo?> {
  bool dismissed = false;
  @override
  UpdateInfo? build() => null;

  Future<UpdateInfo?> check({http.Client? client}) async {
    final u = await checkForUpdate(client: client);
    state = u;
    if (u != null) dismissed = false;
    return u;
  }

  void dismiss() {
    dismissed = true;
    state = null;
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateInfo?>(UpdateNotifier.new);
