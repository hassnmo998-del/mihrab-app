import 'dart:async';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adhan_sound.dart';
import 'adhan_data.dart';

/// Represents Android & System Permission Status for reliable Adhan firing.
class AdhanPermissionsStatus {
  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool batteryOptimizationIgnored;

  const AdhanPermissionsStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.batteryOptimizationIgnored,
  });

  bool get isFullyGuaranteed =>
      notificationsGranted && exactAlarmsGranted && batteryOptimizationIgnored;

  bool get canPlayAdhan => notificationsGranted;
}

/// Represents the prayer countdown state: either before Adhan or between Adhan & Iqama.
enum PrayerCountdownPhase {
  beforeAdhan,
  betweenAdhanAndIqama,
}

class CurrentPrayerState {
  final String prayerName; // e.g. "الفجر", "الظهر", "العصر", "المغرب", "العشاء"
  final DateTime prayerTime;
  final DateTime? iqamaTime;
  final PrayerCountdownPhase phase;
  final Duration remaining;
  final String nextPrayerName;
  final DateTime nextPrayerTime;

  const CurrentPrayerState({
    required this.prayerName,
    required this.prayerTime,
    this.iqamaTime,
    required this.phase,
    required this.remaining,
    required this.nextPrayerName,
    required this.nextPrayerTime,
  });
}

/// Core singleton service managing Adhan playback, 110+ audio catalog,
/// live Iqama countdown tracking, and strict Android background permission checks.
class AdhanService {
  AdhanService._();
  static final AdhanService instance = AdhanService._();

  // Audio Player for Preview & Live Adhan (lazily initialized)
  AudioPlayer? _playerInstance;
  AudioPlayer get _player {
    if (_playerInstance == null) {
      final p = AudioPlayer();
      p.onPlayerStateChanged.listen((state) {
        final isPlaying = state == PlayerState.playing;
        isPlayingNotifier.value = isPlaying;
        if (!isPlaying && state != PlayerState.paused) {
          currentPlayingSoundNotifier.value = null;
          positionNotifier.value = Duration.zero;
          liveFiringPrayerNotifier.value = null;
        }
      });
      p.onPositionChanged.listen((pos) {
        positionNotifier.value = pos;
      });
      p.onDurationChanged.listen((dur) {
        durationNotifier.value = dur;
        isBufferingNotifier.value = false;
      });
      _playerInstance = p;
    }
    return _playerInstance!;
  }

  // Notifiers
  final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<AdhanSound> selectedSoundNotifier =
      ValueNotifier<AdhanSound>(AdhanData.defaultSound);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier =
      ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<AdhanSound?> currentPlayingSoundNotifier =
      ValueNotifier<AdhanSound?>(null);

  // Live Firing Alert (prayer name currently sounding, or null)
  final ValueNotifier<String?> liveFiringPrayerNotifier =
      ValueNotifier<String?>(null);

  // Per-prayer enable map
  final Map<String, bool> _prayerEnabledMap = {
    'الفجر': true,
    'الظهر': true,
    'العصر': true,
    'المغرب': true,
    'العشاء': true,
  };

  // Iqama durations in minutes per prayer
  final Map<String, int> _iqamaMinutesMap = {
    'الفجر': 25,
    'الظهر': 20,
    'العصر': 20,
    'المغرب': 10,
    'العشاء': 15,
  };

  double _volume = 1.0;
  double get volume => _volume;

  // Active Location Coordinates (default Damascus, Syria)
  double _latitude = 33.5138;
  double _longitude = 36.2765;

  Timer? _tickerTimer;
  String? _lastFiredPrayerKey;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Load persisted settings
    await _loadSettings();

    // Start background second-by-second ticker for prayer arrival
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _startTicker();
    }
  }

  void updateLocation(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
  }

  double get latitude => _latitude;
  double get longitude => _longitude;

  bool isPrayerAdhanEnabled(String prayerName) {
    return _prayerEnabledMap[prayerName] ?? true;
  }

  Future<void> setPrayerAdhanEnabled(String prayerName, bool enabled) async {
    _prayerEnabledMap[prayerName] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_prayer_$prayerName', enabled);
  }

  int getIqamaMinutes(String prayerName) {
    return _iqamaMinutesMap[prayerName] ?? 15;
  }

  Future<void> setIqamaMinutes(String prayerName, int minutes) async {
    _iqamaMinutesMap[prayerName] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('iqama_min_$prayerName', minutes);
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    try {
      if (_playerInstance != null) {
        await _playerInstance!.setVolume(_volume);
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('adhan_volume', _volume);
  }

  Future<void> setSelectedSound(AdhanSound sound) async {
    selectedSoundNotifier.value = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhan_selected_sound_id', sound.id);
  }

  Future<void> setAdhanEnabled(bool enabled) async {
    isEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_master_enabled', enabled);
  }

  /// Check detailed permissions on Android
  Future<AdhanPermissionsStatus> checkPermissionsStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const AdhanPermissionsStatus(
        notificationsGranted: true,
        exactAlarmsGranted: true,
        batteryOptimizationIgnored: true,
      );
    }

    // 1. Notification Permission
    bool notifGranted = false;
    try {
      final notifStatus = await Permission.notification.status;
      notifGranted = notifStatus.isGranted;
    } catch (_) {
      notifGranted = true;
    }

    // 2. Exact Alarm Permission (Android 12+)
    bool exactGranted = false;
    try {
      final exactStatus = await Permission.scheduleExactAlarm.status;
      exactGranted = exactStatus.isGranted;
    } catch (_) {
      exactGranted = true;
    }

    // 3. Battery Optimizations Ignored (Doze mode exemption)
    bool batteryIgnored = false;
    try {
      batteryIgnored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      try {
        final batStatus = await Permission.ignoreBatteryOptimizations.status;
        batteryIgnored = batStatus.isGranted;
      } catch (_) {
        batteryIgnored = true;
      }
    }

    return AdhanPermissionsStatus(
      notificationsGranted: notifGranted,
      exactAlarmsGranted: exactGranted,
      batteryOptimizationIgnored: batteryIgnored,
    );
  }

  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    try {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) {
        await openAppSettings();
      }
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      try {
        final status = await Permission.ignoreBatteryOptimizations.request();
        return status.isGranted;
      } catch (_) {
        return false;
      }
    }
  }

  // --- Audio Preview & Controls ---

  Future<void> playPreview(AdhanSound sound) async {
    if (currentPlayingSoundNotifier.value?.id == sound.id &&
        isPlayingNotifier.value) {
      await pause();
      return;
    }

    try {
      isBufferingNotifier.value = true;
      currentPlayingSoundNotifier.value = sound;
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.setSourceUrl(sound.audioUrl);
      await _player.resume();
    } catch (e) {
      isBufferingNotifier.value = false;
      isPlayingNotifier.value = false;
      currentPlayingSoundNotifier.value = null;
    }
  }

  Future<void> playLiveAdhan(String prayerName) async {
    final sound = selectedSoundNotifier.value;
    try {
      liveFiringPrayerNotifier.value = prayerName;
      currentPlayingSoundNotifier.value = sound;
      isBufferingNotifier.value = true;
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.setSourceUrl(sound.audioUrl);
      await _player.resume();
    } catch (_) {
      isBufferingNotifier.value = false;
    }
  }

  Future<void> pause() async {
    try {
      await _playerInstance?.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _playerInstance?.resume();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _playerInstance?.stop();
    } catch (_) {}
    currentPlayingSoundNotifier.value = null;
    liveFiringPrayerNotifier.value = null;
    positionNotifier.value = Duration.zero;
  }

  Future<void> seek(Duration pos) async {
    try {
      await _playerInstance?.seek(pos);
    } catch (_) {}
  }

  // --- Live Calculations & Iqama Tracking ---

  List<Map<String, dynamic>> calculateTodaySchedule({DateTime? forDate}) {
    final now = forDate ?? DateTime.now();
    final coords = Coordinates(_latitude, _longitude);
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi;

    try {
      final pt = PrayerTimes(
        coords,
        DateComponents(now.year, now.month, now.day),
        params,
      );

      return [
        {
          'name': 'الفجر',
          'time': pt.fajr.toLocal(),
          'iqamaMinutes': getIqamaMinutes('الفجر'),
          'hasIqama': true,
        },
        {
          'name': 'الشروق',
          'time': pt.sunrise.toLocal(),
          'iqamaMinutes': 0,
          'hasIqama': false,
        },
        {
          'name': 'الظهر',
          'time': pt.dhuhr.toLocal(),
          'iqamaMinutes': getIqamaMinutes('الظهر'),
          'hasIqama': true,
        },
        {
          'name': 'العصر',
          'time': pt.asr.toLocal(),
          'iqamaMinutes': getIqamaMinutes('العصر'),
          'hasIqama': true,
        },
        {
          'name': 'المغرب',
          'time': pt.maghrib.toLocal(),
          'iqamaMinutes': getIqamaMinutes('المغرب'),
          'hasIqama': true,
        },
        {
          'name': 'العشاء',
          'time': pt.isha.toLocal(),
          'iqamaMinutes': getIqamaMinutes('العشاء'),
          'hasIqama': true,
        },
      ];
    } catch (_) {
      // Fallback in case of computation anomaly
      final y = now.year, m = now.month, d = now.day;
      return [
        {'name': 'الفجر', 'time': DateTime(y, m, d, 4, 42), 'iqamaMinutes': 25, 'hasIqama': true},
        {'name': 'الشروق', 'time': DateTime(y, m, d, 6, 5), 'iqamaMinutes': 0, 'hasIqama': false},
        {'name': 'الظهر', 'time': DateTime(y, m, d, 12, 38), 'iqamaMinutes': 20, 'hasIqama': true},
        {'name': 'العصر', 'time': DateTime(y, m, d, 16, 8), 'iqamaMinutes': 20, 'hasIqama': true},
        {'name': 'المغرب', 'time': DateTime(y, m, d, 18, 55), 'iqamaMinutes': 10, 'hasIqama': true},
        {'name': 'العشاء', 'time': DateTime(y, m, d, 20, 25), 'iqamaMinutes': 15, 'hasIqama': true},
      ];
    }
  }

  /// Evaluates current state: whether counting down to next Adhan or counting down to Iqama!
  CurrentPrayerState getCurrentPrayerState() {
    final now = DateTime.now();
    final todaySchedule = calculateTodaySchedule(forDate: now);

    // 1. Check if we are currently in an Iqama interval for any prayer!
    for (int i = 0; i < todaySchedule.length; i++) {
      final p = todaySchedule[i];
      final pTime = p['time'] as DateTime;
      final int iqamaMin = (p['iqamaMinutes'] as int?) ?? 0;
      final bool hasIqama = p['hasIqama'] == true && iqamaMin > 0;

      if (hasIqama) {
        final iqamaTime = pTime.add(Duration(minutes: iqamaMin));
        // If current time is between Adhan and Iqama
        if (now.isAfter(pTime) && now.isBefore(iqamaTime)) {
          final remainingToIqama = iqamaTime.difference(now);
          // Next prayer will be the one after this
          String nextPName = 'الشروق';
          DateTime nextPTime = todaySchedule[1]['time'] as DateTime;
          if (i + 1 < todaySchedule.length) {
            nextPName = todaySchedule[i + 1]['name'] as String;
            nextPTime = todaySchedule[i + 1]['time'] as DateTime;
          } else {
            // Tomorrow's Fajr
            final tomSchedule = calculateTodaySchedule(
                forDate: now.add(const Duration(days: 1)));
            nextPName = 'الفجر (غداً)';
            nextPTime = tomSchedule.first['time'] as DateTime;
          }

          return CurrentPrayerState(
            prayerName: p['name'] as String,
            prayerTime: pTime,
            iqamaTime: iqamaTime,
            phase: PrayerCountdownPhase.betweenAdhanAndIqama,
            remaining: remainingToIqama,
            nextPrayerName: nextPName,
            nextPrayerTime: nextPTime,
          );
        }
      }
    }

    // 2. Otherwise we are counting down to the upcoming prayer Adhan
    for (int i = 0; i < todaySchedule.length; i++) {
      final p = todaySchedule[i];
      final pTime = p['time'] as DateTime;
      if (pTime.isAfter(now)) {
        return CurrentPrayerState(
          prayerName: p['name'] as String,
          prayerTime: pTime,
          phase: PrayerCountdownPhase.beforeAdhan,
          remaining: pTime.difference(now),
          nextPrayerName: p['name'] as String,
          nextPrayerTime: pTime,
        );
      }
    }

    // 3. Past Isha -> Tomorrow's Fajr
    final tomSchedule =
        calculateTodaySchedule(forDate: now.add(const Duration(days: 1)));
    final tomorrowFajr = tomSchedule.first['time'] as DateTime;
    return CurrentPrayerState(
      prayerName: 'الفجر (غداً)',
      prayerTime: tomorrowFajr,
      phase: PrayerCountdownPhase.beforeAdhan,
      remaining: tomorrowFajr.difference(now),
      nextPrayerName: 'الفجر (غداً)',
      nextPrayerTime: tomorrowFajr,
    );
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkPrayerArrival();
    });
  }

  void stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  void _checkPrayerArrival() {
    final now = DateTime.now();
    final todaySchedule = calculateTodaySchedule(forDate: now);

    for (final p in todaySchedule) {
      final pName = p['name'] as String;
      // Sunrise is not a prayer with Adhan
      if (pName == 'الشروق') continue;

      final pTime = p['time'] as DateTime;
      final diff = now.difference(pTime);

      // Check if prayer time is right now (within 0..3 seconds)
      if (diff.inSeconds >= 0 && diff.inSeconds <= 3) {
        final key = '${now.year}-${now.month}-${now.day}_$pName';
        if (_lastFiredPrayerKey != key) {
          _lastFiredPrayerKey = key;
          _onAdhanTimeReached(pName);
        }
      }
    }
  }

  void _onAdhanTimeReached(String prayerName) {
    if (!isEnabledNotifier.value) return;
    if (!isPrayerAdhanEnabled(prayerName)) return;

    playLiveAdhan(prayerName);
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isEnabledNotifier.value = prefs.getBool('adhan_master_enabled') ?? false;

      final soundId = prefs.getString('adhan_selected_sound_id');
      selectedSoundNotifier.value = AdhanData.getById(soundId);

      _volume = prefs.getDouble('adhan_volume') ?? 1.0;

      for (final p in ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
        _prayerEnabledMap[p] = prefs.getBool('adhan_prayer_$p') ?? true;
        final savedIqama = prefs.getInt('iqama_min_$p');
        if (savedIqama != null) {
          _iqamaMinutesMap[p] = savedIqama;
        }
      }
    } catch (_) {}
  }

  void dispose() {
    _tickerTimer?.cancel();
    try {
      _playerInstance?.dispose();
    } catch (_) {}
  }
}
