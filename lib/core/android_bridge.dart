import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'os.dart';

/// The few things only Android can do for the program, through its own small Android code (android/app/.../MainActivity.kt): open a link,
/// put a file into the phone's Downloads folder, and share a file (straight into one person's WhatsApp chat when a number is given, else the
/// phone's Share menu). On a computer [available] is false and nothing here is used. Tests use a stand-in.
abstract class AndroidBridge {
  bool get available;

  Future<bool> openUrl(String url);

  /// The place shown to the person ("Downloads/ASK ERP 2.0/Bill A-1.pdf"), or null when the phone cannot save there (Android 9 and older).
  Future<String?> saveToDownloads(Uint8List bytes, {required String name, required String mime});

  /// "whatsapp" (the person's chat opened with the file and the words), "menu" (the Share menu opened) or null (nothing could open).
  Future<String?> share(Uint8List bytes, {required String name, required String mime, String text = '', String phone = ''});

  /// The same two for a big file that lies in the program's own folder (a backup): copied by path, never through memory. The copy in
  /// Downloads REPLACES an earlier one of the same name. Returns the place shown to the person, or null when it could not be done.
  Future<String?> copyFileToDownloads(String path, {required String name, required String mime});

  /// "menu" (the Share menu opened) or null.
  Future<String?> shareFile(String path, {required String name, required String mime, String text = ''});
}

class ChannelAndroidBridge implements AndroidBridge {
  const ChannelAndroidBridge();
  static const _ch = MethodChannel('in.senthil.erp2/bridge');

  @override
  bool get available => onAndroid;

  @override
  Future<bool> openUrl(String url) async {
    try {
      return await _ch.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> saveToDownloads(Uint8List bytes, {required String name, required String mime}) async {
    try {
      return await _ch.invokeMethod<String>('saveToDownloads', {'bytes': bytes, 'name': name, 'mime': mime});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> share(Uint8List bytes, {required String name, required String mime, String text = '', String phone = ''}) async {
    try {
      return await _ch.invokeMethod<String>('share', {'bytes': bytes, 'name': name, 'mime': mime, 'text': text, 'phone': phone});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> copyFileToDownloads(String path, {required String name, required String mime}) async {
    try {
      return await _ch.invokeMethod<String>('copyFileToDownloads', {'path': path, 'name': name, 'mime': mime});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> shareFile(String path, {required String name, required String mime, String text = ''}) async {
    try {
      return await _ch.invokeMethod<String>('shareFile', {'path': path, 'name': name, 'mime': mime, 'text': text});
    } catch (_) {
      return null;
    }
  }
}

final androidBridgeProvider = Provider<AndroidBridge>((ref) => const ChannelAndroidBridge());

/// The kind of file, from its name, as Android wants it.
String mimeFor(String fileName) {
  final n = fileName.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (n.endsWith('.csv')) return 'text/csv';
  if (n.endsWith('.json')) return 'application/json';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}
