// ─────────────────────────────────────────────────────────────────────
// PlayerSettings — klassik video player sozlamalari
// ─────────────────────────────────────────────────────────────────────
//
// PDF p22-30: Ekran qulflash, Takrorlash, Tezlik, Sifat, Uyqu taymeri.

class PlayerSettings {
  final double speed;
  final String quality;
  final bool repeat;
  final int? sleepTimerMinutes;
  final bool screenLocked;

  const PlayerSettings({
    this.speed = 1.0,
    this.quality = '720p',
    this.repeat = false,
    this.sleepTimerMinutes,
    this.screenLocked = false,
  });

  PlayerSettings copyWith({
    double? speed,
    String? quality,
    bool? repeat,
    int? sleepTimerMinutes,
    bool clearSleepTimer = false,
    bool? screenLocked,
  }) {
    return PlayerSettings(
      speed: speed ?? this.speed,
      quality: quality ?? this.quality,
      repeat: repeat ?? this.repeat,
      sleepTimerMinutes: clearSleepTimer
          ? null
          : (sleepTimerMinutes ?? this.sleepTimerMinutes),
      screenLocked: screenLocked ?? this.screenLocked,
    );
  }
}
