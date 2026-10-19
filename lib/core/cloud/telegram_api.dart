import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Why a Telegram step failed, in words the screen can explain.
enum TelegramProblem { badToken, badChannel, notAdmin, tooBig, rateLimited, network, noMessage, noBackup, other }

class TelegramFailure implements Exception {
  const TelegramFailure(this.problem, {this.retryAfterSeconds = 0});
  final TelegramProblem problem;
  final int retryAfterSeconds;
  @override
  String toString() => 'TelegramFailure($problem)';
}

/// The small part of the Telegram Bot API the backup needs, over plain HTTPS (no plugin): check the bot, find the channel the bot was added to,
/// send a test message, send a file. The bot token is part of the web address (that is how Telegram works), so it is never printed or logged.
class TelegramApi {
  TelegramApi({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  /// Telegram lets a bot send files up to 50 MB; stay a little below.
  static const maxBytes = 49 * 1024 * 1024;

  Uri _url(String token, String method) => Uri.https('api.telegram.org', '/bot$token/$method');

  Future<Map<String, Object?>> _call(Future<http.Response> Function() send) async {
    final http.Response r;
    try {
      r = await send().timeout(const Duration(minutes: 3));
    } catch (_) {
      throw const TelegramFailure(TelegramProblem.network);
    }
    Map<String, Object?> j = {};
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map) j = d.cast<String, Object?>();
    } catch (_) {}
    if (r.statusCode == 200 && j['ok'] == true) return j;
    final text = '${j['description'] ?? ''}'.toLowerCase();
    final params = j['parameters'];
    if (r.statusCode == 401 || r.statusCode == 404) throw const TelegramFailure(TelegramProblem.badToken);
    if (r.statusCode == 429) throw TelegramFailure(TelegramProblem.rateLimited, retryAfterSeconds: params is Map && params['retry_after'] is int ? params['retry_after'] as int : 30);
    if (r.statusCode == 413 || text.contains('too large')) throw const TelegramFailure(TelegramProblem.tooBig);
    if (r.statusCode == 403 || text.contains('not enough rights') || text.contains('administrator') || text.contains('kicked')) throw const TelegramFailure(TelegramProblem.notAdmin);
    if (r.statusCode == 400 && (text.contains('chat not found') || text.contains('chat_id'))) throw const TelegramFailure(TelegramProblem.badChannel);
    if (r.statusCode >= 500) throw const TelegramFailure(TelegramProblem.network);
    throw const TelegramFailure(TelegramProblem.other);
  }

  /// The bot's @name (proves the token is right).
  Future<String> botName(String token) async {
    final j = await _call(() => _http.get(_url(token, 'getMe')));
    final res = j['result'];
    return res is Map ? '${res['username'] ?? ''}' : '';
  }

  /// The channel the bot was added to: the newest message posted there is looked for. Returns (id, title). Throws [TelegramProblem.noMessage]
  /// when nothing was posted in the channel yet.
  Future<({String id, String title})> findChannel(String token) async {
    final j = await _call(() => _http.get(_url(token, 'getUpdates').replace(queryParameters: {'allowed_updates': '["channel_post"]', 'limit': '100'})));
    final res = j['result'];
    if (res is List) {
      for (final u in res.reversed) {
        final post = u is Map ? u['channel_post'] : null;
        final chat = post is Map ? post['chat'] : null;
        if (chat is Map && chat['id'] != null) return (id: '${chat['id']}', title: '${chat['title'] ?? ''}');
      }
    }
    throw const TelegramFailure(TelegramProblem.noMessage);
  }

  Future<void> sendMessage(String token, String chatId, String text) async {
    await _call(() => _http.post(_url(token, 'sendMessage'), body: {'chat_id': chatId, 'text': text}));
  }

  /// Sends [bytes] as a file called [fileName] to the channel.
  Future<void> sendDocument(String token, String chatId, {required String fileName, required Uint8List bytes, String caption = ''}) async {
    if (bytes.length > maxBytes) throw const TelegramFailure(TelegramProblem.tooBig);
    await _call(() async {
      final req = http.MultipartRequest('POST', _url(token, 'sendDocument'))
        ..fields['chat_id'] = chatId
        ..fields['caption'] = caption
        ..files.add(http.MultipartFile.fromBytes('document', bytes, filename: fileName));
      return http.Response.fromStream(await _http.send(req));
    });
  }
}
