import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short lesson SFX (CLAUDE.md §2, §4.3). All playback is guarded so a missing
/// asset or an unsupported platform (e.g. tests) never throws into the UI, and
/// respects the user's sound toggle.
enum Sfx {
  correct('audio/correct.wav'),
  wrong('audio/wrong.wav'),
  lessonComplete('audio/complete.wav'),
  levelUp('audio/levelup.wav');

  const Sfx(this.asset);
  final String asset;
}

class SoundService {
  SoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// Respects the user's sound toggle (Settings → user_state.sound_enabled).
  bool enabled = true;

  Future<void> play(Sfx sfx) async {
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(sfx.asset));
    } catch (e) {
      // Placeholder assets may be absent during development/tests.
      debugPrint('SoundService: could not play ${sfx.asset}: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}
