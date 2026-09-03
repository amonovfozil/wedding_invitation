import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('weddingMusicAudio')
external web.HTMLAudioElement? get _weddingMusicAudio;

const _musicAssetPath = 'assets/assets/audio/music.mp3';

class WeddingMusicPlayer {
  WeddingMusicPlayer() {
    final existingAudio = _weddingMusicAudio;
    _audio = existingAudio ?? web.HTMLAudioElement();
    final createdAudio = existingAudio == null;

    if (createdAudio) {
      _audio
        ..src = _musicAssetPath
        ..muted = false;
    }
    _audio
      ..preload = 'auto'
      ..autoplay = true
      ..loop = true
      ..controls = false
      ..volume = 0.42;
    _audio.id = 'wedding-music';
    _audio
      ..setAttribute('autoplay', '')
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');
    _audio.style.display = 'none';
    if (_audio.parentElement == null) {
      web.document.body?.appendChild(_audio);
    }
    if (createdAudio) {
      _audio.load();
    }
    _scheduleAutoplayAttempts();
  }

  late final web.HTMLAudioElement _audio;
  final List<Timer> _autoplayTimers = [];

  bool get isPlaying => !_audio.paused && !_audio.muted;

  void _scheduleAutoplayAttempts() {
    unawaited(play());

    for (final delay in const [
      Duration(milliseconds: 350),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
      Duration(milliseconds: 3200),
    ]) {
      _autoplayTimers.add(
        Timer(delay, () {
          if (_audio.paused) {
            unawaited(play());
          }
        }),
      );
    }
  }

  Future<bool> play({bool restart = false, bool userGesture = false}) async {
    try {
      if (restart || _audio.ended) {
        _audio.currentTime = 0;
      }

      if (_audio.muted && !userGesture) {
        return false;
      }

      _audio.muted = false;
      await _audio.play().toDart;
      return isPlaying;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggle() async {
    if (isPlaying) {
      pause();
      return false;
    }
    return play(userGesture: true);
  }

  void pause() {
    _audio.pause();
  }

  void dispose() {
    for (final timer in _autoplayTimers) {
      timer.cancel();
    }
    pause();
  }
}
