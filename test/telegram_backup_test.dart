import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:erp2/core/app_paths_io.dart';
import 'package:erp2/core/cloud/session_vault.dart';
import 'package:erp2/core/cloud/telegram_api.dart';
import 'package:erp2/data/app_data.dart';
import 'package:erp2/data/backup/backup.dart';
import 'package:erp2/data/context.dart';
import 'package:erp2/data/db/app_database.dart';
import 'package:erp2/design/motion_level.dart';
import 'package:erp2/data/db/open.dart';
import 'package:erp2/features/backup/backups_screen.dart';
import 'package:erp2/fake/backup_controller.dart';
import 'package:erp2/fake/data_providers.dart';
import 'package:erp2/fake/health.dart';
import 'package:erp2/fake/store.dart' show clockProvider;
import 'package:erp2/fake/telegram_backup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'data/helpers.dart' as db;
import 'helpers.dart';

// What these tests prove: a backup is locked (AES-256-GCM, password) before it leaves the computer and opens again only with the password; the
// Telegram steps (bot, channel, test message, file) and their errors; the daily rule (evening or closing, once a day, retry after a failure); and
// the Backups / Restore screens that use them.
// What they do NOT prove: that the real Telegram accepts these calls, or the speed of the lock on a real shop file (210,000 password rounds are
// used for real; the tests use 1,000 to stay quick).
const token = '123456789:AAHexampleExampleExampleExample_12345';
const password = 'Kd7p-Mx3q-Rt9w-Ye4n';
const rounds = 1000;

Future<void> real(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 25; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await t.pump(const Duration(milliseconds: 25));
  }
}

/// A pretend Telegram. Keeps what was sent.
class FakeTelegram {
  int documentStatus = 200;
  bool offline = false;
  String? documentText;
  final messages = <String>[];
  final documents = <({String file, String caption, String chat, Uint8List bytes})>[];
  final paths = <String>[];

  MockClient get client => MockClient((req) async {
        if (offline) throw const SocketException('no internet');
        paths.add(req.url.path);
        http.Response ok(Object result) => http.Response(jsonEncode({'ok': true, 'result': result}), 200, headers: {'content-type': 'application/json'});
        if (!req.url.path.startsWith('/bot$token/')) return http.Response(jsonEncode({'ok': false, 'description': 'Unauthorized'}), 401);
        switch (req.url.path.split('/').last) {
          case 'getMe':
            return ok({'username': 'senthil_bot'});
          case 'getUpdates':
            return ok([
              {'channel_post': {'chat': {'id': -1001111, 'title': 'Old'}}},
              {'channel_post': {'chat': {'id': -1002345678, 'title': 'Shop backups'}}},
            ]);
          case 'sendMessage':
            messages.add(req.bodyFields['text'] ?? '');
            return ok({});
          case 'sendDocument':
            if (documentStatus != 200) return http.Response(jsonEncode({'ok': false, 'description': 'Forbidden: not enough rights to send documents'}), documentStatus);
            documents.add(_parse(req));
            return ok({});
        }
        return http.Response('{}', 404);
      });

  /// The file, caption and chat out of a multipart upload.
  ({String file, String caption, String chat, Uint8List bytes}) _parse(http.Request req) {
    final boundary = RegExp('boundary=(.+)').firstMatch(req.headers['content-type']!)!.group(1)!;
    final body = req.bodyBytes;
    final text = latin1.decode(body);
    final parts = text.split('--$boundary');
    String field(String name) {
      for (final part in parts) {
        if (part.contains('name="$name"') && !part.contains('filename=')) return part.split('\r\n\r\n')[1].replaceAll(RegExp(r'\r\n$'), '');
      }
      return '';
    }

    final start = text.indexOf('filename="');
    final fileName = text.substring(start + 10, text.indexOf('"', start + 10));
    final dataStart = text.indexOf('\r\n\r\n', start) + 4;
    final dataEnd = text.indexOf('\r\n--$boundary', dataStart);
    return (file: fileName, caption: utf8.decode(latin1.encode(field('caption'))), chat: field('chat_id'), bytes: Uint8List.fromList(body.sublist(dataStart, dataEnd)));
  }
}

void main() {
  setUpAll(() => runBackupWorkInline = true);
  tearDownAll(() => runBackupWorkInline = false);

  group('the lock', () {
    final plain = Uint8List.fromList(List.generate(200000, (i) => i % 7 == 0 ? 0 : (i * 31) % 251));

    test('opens only with the password; the same backup locked twice looks different; the locked file is smaller (zeros compress)', () async {
      final a = await sealBackup(plain, password, rounds: rounds);
      final b = await sealBackup(plain, password, rounds: rounds);
      expect(a, isNot(b), reason: 'a new random salt and nonce every time');
      expect(a.length, lessThan(plain.length));
      expect(looksSealed(a), isTrue);
      expect(await openSealedBackup(a, password), plain);
      await expectLater(openSealedBackup(a, 'not the password'), throwsA(isA<SealException>().having((e) => e.problem, 'problem', SealProblem.wrongPassword)));
    });

    test('one changed byte anywhere (data, seal, salt, nonce, rounds) is refused: nothing is half-opened', () async {
      final a = await sealBackup(plain, password, rounds: rounds);
      for (final i in [20, 30, 100, a.length ~/ 2, a.length - 1]) {
        final bad = Uint8List.fromList(a)..[i] ^= 1;
        await expectLater(openSealedBackup(bad, password), throwsA(isA<SealException>()), reason: 'byte $i');
      }
    });

    test('a file that is not ours, or too short, or asks for absurd work, is refused quickly', () async {
      await expectLater(openSealedBackup(Uint8List.fromList(utf8.encode('SQLite format 3\u0000 and more bytes to be long enough ......')), password), throwsA(isA<SealException>().having((e) => e.problem, 'problem', SealProblem.notSealed)));
      await expectLater(openSealedBackup(Uint8List(10), password), throwsA(isA<SealException>().having((e) => e.problem, 'problem', SealProblem.notSealed)));
      final a = await sealBackup(plain, password, rounds: rounds);
      final crafted = Uint8List.fromList(a)..buffer.asByteData().setUint32(8, 0x7FFFFFFF);
      final sw = Stopwatch()..start();
      await expectLater(openSealedBackup(crafted, password), throwsA(isA<SealException>().having((e) => e.problem, 'problem', SealProblem.damaged)));
      expect(sw.elapsedMilliseconds, lessThan(500), reason: 'a crafted file cannot tie the computer up');
    });

    test('the password the program makes: four groups of four, no look-alike characters; short passwords are refused', () {
      final pw = makeBackupPassword();
      expect(pw, matches(RegExp(r'^[a-zA-Z2-9]{4}(-[a-zA-Z2-9]{4}){3}$')));
      expect(pw, isNot(matches(RegExp(r'[0OIl1]'))));
      expect(makeBackupPassword(), isNot(pw));
      expect(goodBackupPassword(pw), isTrue);
      expect(goodBackupPassword('short'), isFalse);
      expect(goodBackupPassword(' padded-password '), isFalse);
    });
  });

  group('TelegramApi', () {
    TelegramApi api(FakeTelegram t) => TelegramApi(client: t.client);

    test('bot name, channel found from the newest post, test message, file with its caption', () async {
      final t = FakeTelegram();
      expect(await api(t).botName(token), 'senthil_bot');
      final ch = await api(t).findChannel(token);
      expect((ch.id, ch.title), ('-1002345678', 'Shop backups'));
      await api(t).sendMessage(token, ch.id, 'hello');
      expect(t.messages, ['hello']);
      await api(t).sendDocument(token, ch.id, fileName: 'x.askbak', bytes: Uint8List.fromList([1, 2, 3, 0, 255, 13, 10, 4]), caption: 'Senthil backup');
      expect(t.documents.single.file, 'x.askbak');
      expect(t.documents.single.chat, '-1002345678');
      expect(t.documents.single.caption, 'Senthil backup');
      expect(t.documents.single.bytes, [1, 2, 3, 0, 255, 13, 10, 4]);
    });

    test('each failure is told apart: wrong token, no admin rights, no internet, a channel with no post yet, a file over 50 MB', () async {
      final t = FakeTelegram();
      Matcher problem(TelegramProblem x) => throwsA(isA<TelegramFailure>().having((e) => e.problem, 'problem', x));
      await expectLater(api(t).botName('999:wrong'), problem(TelegramProblem.badToken));
      t.documentStatus = 403;
      await expectLater(api(t).sendDocument(token, '-1', fileName: 'x', bytes: Uint8List(5)), problem(TelegramProblem.notAdmin));
      t.offline = true;
      await expectLater(api(t).botName(token), problem(TelegramProblem.network));
      final empty = TelegramApi(client: MockClient((_) async => http.Response(jsonEncode({'ok': true, 'result': []}), 200)));
      await expectLater(empty.findChannel(token), problem(TelegramProblem.noMessage));
      await expectLater(api(FakeTelegram()).sendDocument(token, '-1', fileName: 'big', bytes: Uint8List(TelegramApi.maxBytes + 1)), problem(TelegramProblem.tooBig));
      final limited = TelegramApi(client: MockClient((_) async => http.Response(jsonEncode({'ok': false, 'parameters': {'retry_after': 17}}), 429)));
      await expectLater(limited.botName(token), throwsA(isA<TelegramFailure>().having((e) => e.retryAfterSeconds, 'retry_after', 17)));
    });
  });

  group('the daily send', () {
    late Directory dir;
    late AppDatabase database;
    late AppData d;
    late ProviderContainer c;
    late FileAppPaths paths;
    late FakeTelegram tg;
    late MemorySessionVault vault;
    late String folder;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('tgbk');
      paths = FileAppPaths(p.join(dir.path, 'ASK ERP 2.0'));
      final live = paths.dbLocation('shop');
      database = await openShopDatabase(live);
      d = AppData(DataContext(db: database, deviceId: 'dev-test'));
      await d.settings.put('shop.id', 'shop-A');
      await d.catalog.saveProduct(db.sampleProduct('Pipe', id: 'p1'), create: true);
      tg = FakeTelegram();
      vault = MemorySessionVault();
      folder = p.join(dir.path, 'Backups');
      c = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(DateTime(2026, 10, 14, 10, 0)), // a fixed morning: after 8 PM a finished backup is also sent by itself, which these tests must not depend on
        appPathsProvider.overrideWithValue(paths),
        dbFilePathProvider.overrideWithValue(live),
        appDataProvider.overrideWithValue(d),
        deviceIdProvider.overrideWithValue('abcdef12-0000'),
        telegramApiProvider.overrideWithValue(TelegramApi(client: tg.client)),
        telegramVaultProvider.overrideWithValue(vault),
        sealRoundsProvider.overrideWithValue(rounds),
      ]);
      await paths.writeText('backup.folder', folder);
      await c.read(backupControllerProvider.notifier).load();
    });
    tearDown(() async {
      c.dispose();
      await database.close();
      dir.deleteSync(recursive: true);
    });

    TelegramBackupController ctl() => c.read(telegramBackupProvider.notifier);

    Future<BackupInfo> backup(BackupKind kind, DateTime at) => createBackup(livePath: paths.dbLocation('shop'), folder: folder, deviceId: 'abcdef12-0000', appVersion: '2.0.0', kind: kind, now: at, freeBytesOverride: 1 << 40);

    test('connect: the bot is checked, the channel is found, a test message is sent, and the settings are kept encrypted on this computer only', () async {
      expect(await ctl().connect(token: 'wrong', password: password), TelegramProblem.badToken);
      expect(c.read(telegramBackupProvider).configured, isFalse);
      expect(await ctl().connect(token: token, password: password), isNull);
      final s = c.read(telegramBackupProvider);
      expect((s.configured, s.channel, s.bot), (true, 'Shop backups', 'senthil_bot'));
      expect(tg.messages.single, contains('backups are connected'));
      expect(jsonDecode(vault.read()!)['chat'], '-1002345678');
      // the next start of the program finds it again
      final again = ProviderContainer(overrides: [telegramVaultProvider.overrideWithValue(vault), telegramApiProvider.overrideWithValue(TelegramApi(client: tg.client)), appPathsProvider.overrideWithValue(paths), dbFilePathProvider.overrideWithValue(paths.dbLocation('shop')), appDataProvider.overrideWithValue(d)]);
      addTearDown(again.dispose);
      expect(again.read(telegramBackupProvider).configured, isTrue);
    });

    test('Send now: a fresh backup is made, locked, sent; what arrives opens ONLY with the password and is exactly the backup file', () async {
      await ctl().connect(token: token, password: password);
      expect(await ctl().sendNow(), isNull);
      final sent = tg.documents.single;
      expect(sent.file, matches(RegExp(r'^ASKERP_.*_manual\.sqlite\.askbak$')));
      expect(sent.chat, '-1002345678');
      expect(sent.caption, contains('backup, locked'));
      expect(looksSealed(sent.bytes), isTrue);
      expect(latin1.decode(sent.bytes), isNot(contains('SQLite format')), reason: 'nothing readable leaves the computer');
      final file = listBackups(folder).single;
      expect(await openSealedBackup(sent.bytes, password), File(file.path).readAsBytesSync());
      await expectLater(openSealedBackup(sent.bytes, 'wrong password'), throwsA(isA<SealException>()));
      final s = c.read(telegramBackupProvider);
      expect(s.lastSent, isNotNull);
      expect(s.lastBytes, sent.bytes.length);
      expect(s.problem, isNull);
    });

    test('the daily rule: not before 8 PM, then once; the closing backup goes at any hour; safety copies never; the next day again', () async {
      await ctl().connect(token: token, password: password);
      final morning = await backup(BackupKind.auto, DateTime(2026, 10, 14, 10, 0));
      await ctl().afterLocalBackup(morning.path, now: DateTime(2026, 10, 14, 10, 0));
      expect(tg.documents, isEmpty, reason: 'too early: the evening copy is the one to send');
      final evening = await backup(BackupKind.auto, DateTime(2026, 10, 14, 20, 5));
      await ctl().afterLocalBackup(evening.path, now: DateTime(2026, 10, 14, 20, 5));
      expect(tg.documents, hasLength(1));
      final later = await backup(BackupKind.auto, DateTime(2026, 10, 14, 22, 0));
      await ctl().afterLocalBackup(later.path, now: DateTime(2026, 10, 14, 22, 0));
      expect(tg.documents, hasLength(1), reason: 'once a day');
      final safety = await backup(BackupKind.safety, DateTime(2026, 10, 15, 21, 0));
      await ctl().afterLocalBackup(safety.path, now: DateTime(2026, 10, 15, 21, 0));
      expect(tg.documents, hasLength(1), reason: 'a safety copy before a restore is not for Telegram');
      final closing = await backup(BackupKind.closing, DateTime(2026, 10, 15, 9, 0));
      await ctl().afterLocalBackup(closing.path, now: DateTime(2026, 10, 15, 9, 0));
      expect(tg.documents, hasLength(2), reason: 'the next day, and the closing backup goes at any hour');
    });

    test('the routine backups update one file: each evening copy still goes once a day, and in the channel each copy has its date in its name', () async {
      await ctl().connect(token: token, password: password);
      Future<BackupInfo> roll(DateTime at, BackupKind kind) =>
          createBackup(livePath: paths.dbLocation('shop'), folder: folder, deviceId: 'abcdef12-0000', appVersion: '2.0.0', kind: kind, now: at, rolling: true, freeBytesOverride: 1 << 40);
      final morning = await roll(DateTime(2026, 10, 14, 10, 0), BackupKind.auto);
      await ctl().afterLocalBackup(morning.path, now: DateTime(2026, 10, 14, 10, 0), kind: BackupKind.auto);
      expect(tg.documents, isEmpty, reason: 'too early');
      final evening = await roll(DateTime(2026, 10, 14, 20, 5), BackupKind.auto);
      expect(evening.path, morning.path, reason: 'the same file on this computer');
      await ctl().afterLocalBackup(evening.path, now: DateTime(2026, 10, 14, 20, 5), kind: BackupKind.auto);
      expect(tg.documents, hasLength(1));
      expect(tg.documents.single.file, 'ASKERP_20261014-200500_abcdef12_v2.0.0-proto.3_auto.sqlite.askbak', reason: 'the channel copy carries its date and why it was made');
      await ctl().afterLocalBackup((await roll(DateTime(2026, 10, 14, 22, 0), BackupKind.auto)).path, now: DateTime(2026, 10, 14, 22, 0), kind: BackupKind.auto);
      expect(tg.documents, hasLength(1), reason: 'once a day');
      await ctl().afterLocalBackup((await roll(DateTime(2026, 10, 15, 9, 0), BackupKind.closing)).path, now: DateTime(2026, 10, 15, 9, 0), kind: BackupKind.closing);
      expect(tg.documents, hasLength(2), reason: 'the next day, and a closing backup goes at any hour');
      expect(tg.documents.last.file, contains('_closing.sqlite.askbak'));
      expect(tg.documents.map((d) => d.file).toSet().length, 2, reason: 'different names in the channel');
    });

    test('a failure is shown and the next backup tries again; a file is never sent twice', () async {
      await ctl().connect(token: token, password: password);
      tg.documentStatus = 403;
      final first = await backup(BackupKind.auto, DateTime(2026, 10, 14, 21, 0));
      await ctl().afterLocalBackup(first.path, now: DateTime(2026, 10, 14, 21, 0));
      expect(c.read(telegramBackupProvider).problem, TelegramProblem.notAdmin);
      expect(c.read(telegramBackupProvider).lastSent, isNull);
      tg.documentStatus = 200;
      await ctl().afterLocalBackup(first.path, now: DateTime(2026, 10, 14, 21, 30));
      expect(tg.documents, hasLength(1), reason: 'the same file is tried again once the problem is gone');
      expect(c.read(telegramBackupProvider).problem, isNull);
      await ctl().afterLocalBackup(first.path, now: DateTime(2026, 10, 14, 23, 0));
      expect(tg.documents, hasLength(1));
      tg.offline = true;
      final next = await backup(BackupKind.auto, DateTime(2026, 10, 15, 21, 0));
      await ctl().afterLocalBackup(next.path, now: DateTime(2026, 10, 15, 21, 0));
      expect(c.read(telegramBackupProvider).problem, TelegramProblem.network);
    });

    test('Turn off forgets the token, the channel and the password', () async {
      await ctl().connect(token: token, password: password);
      ctl().forget();
      expect(c.read(telegramBackupProvider).configured, isFalse);
      expect(vault.read(), isNull);
      await ctl().afterLocalBackup((await backup(BackupKind.auto, DateTime(2026, 10, 14, 21, 0))).path, now: DateTime(2026, 10, 14, 21, 0));
      expect(tg.documents, isEmpty);
    });
  });

  group('screens', () {
    Future<(ProviderContainer, FakeTelegram, Directory, FileAppPaths)> open(WidgetTester tester, String location, {FakeTelegram? fake, Future<String?> Function()? sealedPicker}) async {
      final dir = Directory.systemTemp.createTempSync('tgui');
      addTearDown(() => dir.deleteSync(recursive: true));
      final paths = FileAppPaths(p.join(dir.path, 'ASK ERP 2.0'));
      final live = paths.dbLocation('shop');
      await tester.runAsync(() async {
        final database = await openShopDatabase(live);
        final data = AppData(DataContext(db: database, deviceId: 'dev-test'));
        await data.settings.put('shop.id', 'shop-A');
        await data.catalog.saveProduct(db.sampleProduct('Item', id: 'p1'), create: true);
        await database.close();
        await paths.writeText('backup.folder', p.join(dir.path, 'Backups'));
      });
      final tg = fake ?? FakeTelegram();
      final c = await pumpApp(tester, size: const ScreenSpec('tall', 1366, 2600), location: location, motion: MotionLevel.off, followSystemMotion: false, extraOverrides: [
        appPathsProvider.overrideWithValue(paths),
        dbFilePathProvider.overrideWithValue(live),
        deviceIdProvider.overrideWithValue('abcdef12-0000'),
        dataDirProvider.overrideWithValue(paths.dataDir),
        telegramApiProvider.overrideWithValue(TelegramApi(client: tg.client)),
        telegramVaultProvider.overrideWithValue(MemorySessionVault()),
        sealRoundsProvider.overrideWithValue(rounds),
        if (sealedPicker != null) sealedFilePickerProvider.overrideWithValue(sealedPicker),
      ]);
      await tester.runAsync(() => c.read(backupControllerProvider.notifier).load());
      await real(tester, 100);
      return (c, tg, dir, paths);
    }

    testWidgets('the Backups page: Set up is offered; once connected it shows the channel; Send now sends a locked copy; Turn off forgets', (tester) async {
      final (c, tg, _, _) = await open(tester, '/backups');
      expect(find.byKey(const ValueKey('tgSetup')), findsOneWidget);
      await tester.runAsync(() => c.read(telegramBackupProvider.notifier).connect(token: token, password: password));
      await real(tester, 100);
      expect(find.byKey(const ValueKey('tgConnected')), findsOneWidget);
      expect(find.textContaining('Shop backups'), findsWidgets);
      expect(find.text('Nothing sent yet'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('tgSendNow')));
      await tester.tap(find.byKey(const ValueKey('tgSendNow')));
      await real(tester, 3000);
      expect(tg.documents, hasLength(1));
      expect(find.textContaining('Last sent:'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('tgForget')));
      await tester.tap(find.byKey(const ValueKey('tgForget')));
      await real(tester, 100);
      expect(find.byKey(const ValueKey('tgSetup')), findsOneWidget);
    });

    testWidgets('Restore: a locked file from Telegram needs the password; a wrong one is refused in plain words; the right one is checked like any backup', (tester) async {
      String? picked;
      final lockedDir = Directory.systemTemp.createTempSync('tgseal');
      addTearDown(() => lockedDir.deleteSync(recursive: true));
      final (_, _, dir, paths) = await open(tester, '/restore', sealedPicker: () async => picked);
      await tester.runAsync(() async {
        final info = await createBackup(livePath: paths.dbLocation('shop'), folder: p.join(dir.path, 'Backups'), deviceId: 'abcdef12-0000', appVersion: '2.0.0', kind: BackupKind.manual, freeBytesOverride: 1 << 40);
        picked = p.join(lockedDir.path, '${info.name}.askbak');
        File(picked!).writeAsBytesSync(await sealBackupFile(info.path, password, rounds: rounds));
      });
      await tester.ensureVisible(find.byKey(const ValueKey('chooseSealedFile')));
      await tester.tap(find.byKey(const ValueKey('chooseSealedFile')));
      await real(tester, 200);
      await tester.enterText(find.byType(TextFormField).last, 'the wrong password');
      await tester.tap(find.text('Open'));
      await real(tester, 3000);
      expect(find.text('Wrong password, or the file is damaged.'), findsOneWidget);
      expect(find.byKey(const ValueKey('restoreNow')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('chooseSealedFile')));
      await tester.tap(find.byKey(const ValueKey('chooseSealedFile')));
      await real(tester, 200);
      await tester.enterText(find.byType(TextFormField).last, password);
      await tester.tap(find.text('Open'));
      await real(tester, 3000);
      expect(find.byKey(const ValueKey('restoreNow')), findsOneWidget, reason: 'opened, checked, and ready to restore like any backup');
    });
  });
}
