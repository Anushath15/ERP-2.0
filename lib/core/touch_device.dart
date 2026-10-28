import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'os.dart';

/// True on a real phone or tablet (Android, iPhone). A computer window that is narrow, or shows big text, also gets the phone layout, but it is not a
/// touch device and keeps its pages exactly as they were: every phone-only improvement is switched on by this, never by the window size alone.
/// Tests switch it on to try the phone-only parts.
final touchDeviceProvider = Provider<bool>((ref) => onAndroid || onIos);

/// The same, for a widget that has no `ref` (and still works where there is no provider scope).
bool isTouchDevice(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false).read(touchDeviceProvider);
  } catch (_) {
    return onAndroid || onIos;
  }
}
