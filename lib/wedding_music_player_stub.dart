class WeddingMusicPlayer {
  bool get isPlaying => false;

  Future<bool> play({bool restart = false, bool userGesture = false}) async =>
      false;

  Future<bool> toggle() async => false;

  void pause() {}

  void dispose() {}
}
