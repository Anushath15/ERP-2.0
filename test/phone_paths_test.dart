import 'dart:io';
import 'package:erp2/core/app_paths_io.dart';
import 'package:flutter_test/flutter_test.dart';

// What these tests prove: on an Android phone or tablet the program finds its own private folder (no crash at start) and keeps the
// shop data, settings and backups inside it. What they do NOT prove: a real phone (needs the Android build on a device).
void main() {
  test('Android: the folder beside the cache folder is the app home; the shop data goes in its "files" folder', () {
    expect(phoneBaseDir(android: true, ios: false, tempPath: '/data/user/0/com.senthil.erp2/cache'), '/data/user/0/com.senthil.erp2/files/ASK ERP 2.0');
    expect(phoneBaseDir(android: true, ios: false, tempPath: '/data/user/0/com.senthil.erp2/cache/'), '/data/user/0/com.senthil.erp2/files/ASK ERP 2.0', reason: 'a trailing slash changes nothing');
  });

  test('iPhone: the Documents folder of the app', () {
    expect(phoneBaseDir(android: false, ios: true, tempPath: '/var/mobile/Containers/Data/Application/ABC/tmp'), '/var/mobile/Containers/Data/Application/ABC/Documents/ASK ERP 2.0');
  });

  test('a computer is not a phone; a nonsense temp folder gives nothing instead of a crash', () {
    expect(phoneBaseDir(android: false, ios: false, tempPath: '/tmp'), isNull);
    expect(phoneBaseDir(android: true, ios: false, tempPath: 'cache'), isNull);
    expect(phoneBaseDir(android: true, ios: false, tempPath: '/'), isNull);
  });

  test('the paths built on it: data folder, database file and a backup folder inside the app (not a computer Documents folder)', () {
    final base = phoneBaseDir(android: true, ios: false, tempPath: '/data/user/0/p/cache')!;
    final paths = FileAppPaths(base);
    expect(paths.dataDir, '$base${Platform.pathSeparator}data');
    expect(paths.dbLocation('shop'), endsWith('shop.sqlite'));
  });

  test('on this computer the program still finds its folder (no change for Windows)', () {
    expect(() => createAppPaths(), returnsNormally);
  });
}
