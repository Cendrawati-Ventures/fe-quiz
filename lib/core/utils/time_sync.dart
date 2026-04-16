class TimeSync {
  Duration _serverOffset = Duration.zero;

  void syncFromServerUtc(DateTime serverUtc) {
    final localUtc = DateTime.now().toUtc();
    _serverOffset = serverUtc.difference(localUtc);
  }

  void syncFromServerEpochMs(int serverEpochMs) {
    syncFromServerUtc(
      DateTime.fromMillisecondsSinceEpoch(serverEpochMs, isUtc: true),
    );
  }

  DateTime nowServerUtc() {
    return DateTime.now().toUtc().add(_serverOffset);
  }
}
