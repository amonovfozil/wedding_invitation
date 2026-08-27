import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('weddingMusicAudio')
external web.HTMLAudioElement? get _weddingMusicAudio;

class WeddingMusicPlayer {
  WeddingMusicPlayer() {
    _audio
      ..src = 'assets/assets/audio/music.mp3'
      ..preload = 'auto'
      ..autoplay = true
      ..loop = true
      ..controls = false
      ..muted = false
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
    _audio.load();
    _scheduleAutoplayAttempts();
  }

  final web.HTMLAudioElement _audio =
      _weddingMusicAudio ?? web.HTMLAudioElement();
  final List<Timer> _autoplayTimers = [];

  bool get isPlaying => !_audio.paused;

  void _scheduleAutoplayAttempts() {
    unawaited(play(restart: true));

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

  Future<bool> play({bool restart = false}) async {
    try {
      if (restart || _audio.ended) {
        _audio.currentTime = 0;
      }
      _audio.muted = false;
      await _audio.play().toDart;
      return true;
    } catch (_) {
      try {
        _audio.muted = true;
        await _audio.play().toDart;
        Timer(const Duration(milliseconds: 160), () {
          _audio.muted = false;
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> toggle() async {
    if (isPlaying) {
      pause();
      return false;
    }
    return play();
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
