import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_info.dart';
import '../core/cloud/session_vault.dart';
import '../core/cloud/telegram_api.dart';
import '../data/backup/backup.dart';
import 'backup_controller.dart';
import 'shop_profile.dart';
import 'store.dart' show clockProvider;

final telegramApiProvider = Provider<TelegramApi>((ref) => TelegramApi());

/// How many password rounds the lock uses (only tests make it smaller, to be quick).
final sealRoundsProvider = Provider<int>((ref) => defaultRounds);

class TelegramState {
  const TelegramState({this.configured = false, this.channel = '', this.bot = '', this.lastSent, this.lastBytes = 0, this.problem, this.busy = false});
  final bool configured, busy;
  final String channel, bot;
  final DateTime? lastSent;
  final int lastBytes;

  /// What went wrong the last time, or null.
  final TelegramProblem? problem;

  TelegramState copyWith({bool? configured, String? channel, String? bot, DateTime? lastSent, int? lastBytes, TelegramProblem? problem, bool clearProblem = false, bool? busy}) => TelegramState(
        configured: configured ?? this.configured,
        channel: channel ?? this.channel,
        bot: bot ?? this.bot,
        lastSent: lastSent ?? this.lastSent,
        lastBytes: lastBytes ?? this.lastBytes,
        problem: clearProblem ? null : (problem ?? this.problem),
        busy: busy ?? this.busy,
      );
}

/// A locked (encrypted) copy of the day's backup, sent to the owner's private Telegram channel by the owner's own bot.
///  * Once a day, in the evening (from 8 PM) or when the program closes, after a good local backup; never twice in a day unless asked ("Send now").
///  * The file is compressed and locked with AES-256 under the owner's backup password BEFORE it leaves this computer: Telegram only ever holds
///    something nobody can read. The bot token, channel and password are kept encrypted for this Windows user (like the sign-in).
///  * It is an extra copy, not the only one: the local backups stay. If it cannot be sent (no internet, bot removed), the screen says so and the
///    next backup tries again.
class TelegramBackupController extends Notifier<TelegramState> {
  String _token = '', _chat = '', _password = '';
  String? _handled; // the backup file already sent (or being sent), so one file is never sent twice

  /// From this hour of the day a finished backup is sent (the day's first one after it).
  static const sendFromHour = 20;

  SessionVault get _vault => ref.read(telegramVaultProvider);
  TelegramApi get _api => ref.read(telegramApiProvider);

  @override
  TelegramState build() {
    // a finished local backup may be due to go to Telegram
    ref.listen(backupControllerProvider.select((s) => s.lastFile), (prev, next) {
      if (next != null && next != prev) unawaited(afterLocalBackup(next));
    });
    try {
      final j = jsonDecode(_vault.read() ?? '');
      if (j is Map && '${j['token'] ?? ''}'.isNotEmpty && '${j['chat'] ?? ''}'.isNotEmpty && '${j['password'] ?? ''}'.isNotEmpty) {
        _token = '${j['token']}';
        _chat = '${j['chat']}';
        _password = '${j['password']}';
        final ms = j['lastSent'] is int ? j['lastSent'] as int : null;
        return TelegramState(configured: true, channel: '${j['title'] ?? ''}', bot: '${j['bot'] ?? ''}', lastSent: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms), lastBytes: j['lastBytes'] is int ? j['lastBytes'] as int : 0);
      }
    } catch (_) {}
    return const TelegramState();
  }

  String get _shopName {
    try {
      final n = ref.read(shopProvider).name.trim();
      return n.isEmpty ? 'Shop' : n;
    } catch (_) {
      return 'Shop'; // the shop profile is not loaded (never in the program, only in a bare test)
    }
  }

  void _save() => _vault.write(jsonEncode({
        'token': _token,
        'chat': _chat,
        'password': _password,
        'title': state.channel,
        'bot': state.bot,
        'lastSent': state.lastSent?.millisecondsSinceEpoch,
        'lastBytes': state.lastBytes,
      }));

  /// Checks the bot and the channel, sends a test message, and keeps the settings. [chatId] can be given by hand (an @name or a number);
  /// when empty the channel is found from the newest message posted in it. Returns null when connected, else what is wrong.
  Future<TelegramProblem?> connect({required String token, required String password, String chatId = ''}) async {
    final t = token.trim();
    if (state.busy) return null;
    state = state.copyWith(busy: true, clearProblem: true);
    try {
      final bot = await _api.botName(t);
      var chat = chatId.trim();
      var title = chat;
      if (chat.isEmpty) {
        final found = await _api.findChannel(t);
        chat = found.id;
        title = found.title.isEmpty ? found.id : found.title;
      }
      await _api.sendMessage(t, chat, '✅ ASK ERP 2.0 backups are connected. A locked copy of the shop data will arrive here every evening.');
      _token = t;
      _chat = chat;
      _password = password;
      state = TelegramState(configured: true, channel: title, bot: bot, lastSent: state.lastSent, lastBytes: state.lastBytes);
      _save();
      return null;
    } on TelegramFailure catch (e) {
      state = state.copyWith(busy: false, problem: e.problem);
      return e.problem;
    }
  }

  /// Turns Telegram backups off and forgets the token, the channel and the password on this computer (files already in the channel stay there).
  void forget() {
    _token = _chat = _password = '';
    _vault.write(null);
    state = const TelegramState();
  }

  /// A new local backup was made: send it when it is time (the day's first one from 8 PM, or the closing one). [file] is the backup's path.
  Future<void> afterLocalBackup(String file, {DateTime? now}) async {
    if (!state.configured || state.busy || _handled == file) return;
    final info = BackupInfo.fromName(file, file.split(RegExp(r'[\\/]')).last);
    if (info == null || info.kind == BackupKind.safety || info.kind == BackupKind.archive) return;
    final DateTime t = now ?? ref.read(clockProvider);
    final last = state.lastSent;
    final sentToday = last != null && last.year == t.year && last.month == t.month && last.day == t.day;
    if (sentToday) return;
    if (t.hour < sendFromHour && info.kind != BackupKind.closing) return;
    await _upload(file, t);
  }

  /// "Send now": makes a fresh backup first, then sends it. Returns null when sent, else what is wrong.
  Future<TelegramProblem?> sendNow() async {
    if (!state.configured || state.busy) return null;
    final ctrl = ref.read(backupControllerProvider.notifier);
    if (!await ctrl.run(BackupKind.manual)) {
      state = state.copyWith(problem: TelegramProblem.noBackup);
      return TelegramProblem.noBackup;
    }
    final file = ref.read(backupControllerProvider).lastFile;
    if (file == null) return TelegramProblem.noBackup;
    _handled = null;
    await _upload(file, ref.read(clockProvider));
    return state.problem;
  }

  Future<void> _upload(String file, DateTime sentAt) async {
    _handled = file;
    state = state.copyWith(busy: true, clearProblem: true);
    try {
      final sealed = await sealBackupFile(file, _password, rounds: ref.read(sealRoundsProvider));
      final name = '${file.split(RegExp(r'[\\/]')).last}.askbak';
      final mb = (sealed.length / (1024 * 1024)).toStringAsFixed(1);
      await _api.sendDocument(_token, _chat, fileName: name, bytes: sealed, caption: '$_shopName backup, locked. $mb MB. Program $appVersionLabel.');
      state = state.copyWith(busy: false, lastSent: sentAt, lastBytes: sealed.length, clearProblem: true);
      _save();
    } on TelegramFailure catch (e) {
      _handled = null; // the next backup tries again
      state = state.copyWith(busy: false, problem: e.problem);
    } on BackupException {
      _handled = null;
      state = state.copyWith(busy: false, problem: TelegramProblem.noBackup);
    } catch (_) {
      _handled = null;
      state = state.copyWith(busy: false, problem: TelegramProblem.other);
    }
  }
}

final telegramBackupProvider = NotifierProvider<TelegramBackupController, TelegramState>(TelegramBackupController.new);
