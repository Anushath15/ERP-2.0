import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../fake/store.dart';

enum SoundKind { scan, save, error }

/// Plays the optional sounds. In this preview it uses the system sound (no audio plugin, so the volume setting is stored
/// but only takes effect when real audio playback is added in Phase 2). Playing is fire-and-forget: it never delays the action.
abstract class SoundPlayer {
  void play(SoundKind kind, double volume);
}

class SystemSoundPlayer implements SoundPlayer {
  const SystemSoundPlayer();
  @override
  void play(SoundKind kind, double volume) {
    if (volume <= 0) return;
    SystemSound.play(kind == SoundKind.error ? SystemSoundType.alert : SystemSoundType.click);
  }
}

final soundPlayerProvider = Provider<SoundPlayer>((ref) => const SystemSoundPlayer());

/// Plays a sound if the owner turned it on in Settings > Sounds.
void playSound(WidgetRef ref, SoundKind kind) {
  final s = ref.read(settingsProvider);
  final on = switch (kind) { SoundKind.scan => s.soundScan, SoundKind.save => s.soundSave, SoundKind.error => s.soundError };
  if (on) ref.read(soundPlayerProvider).play(kind, s.soundVolume);
}

/// Same as [playSound] for widgets that are not Riverpod consumers (dialogs, forms).
void playSoundIn(BuildContext context, SoundKind kind) {
  final c = ProviderScope.containerOf(context, listen: false);
  final st = c.read(settingsProvider);
  final on = switch (kind) { SoundKind.scan => st.soundScan, SoundKind.save => st.soundSave, SoundKind.error => st.soundError };
  if (on) c.read(soundPlayerProvider).play(kind, st.soundVolume);
}
