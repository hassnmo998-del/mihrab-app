import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/astro/sky_track.dart';
import '../models/adhan_sound.dart';
import '../models/prayer_calculation_settings.dart';
import 'adhan_audio_cache_manager.dart';
import 'adhan_data.dart';
import 'app_notification_service.dart';
import 'background_audio.dart';

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
enum PrayerCountdownPhase { beforeAdhan, betweenAdhanAndIqama }

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
class AdhanService implements BackgroundAudioSource {
  AdhanService._() {
    // تنزيل الأصوات يكمل في الخلفية وبعد إعادة فتح التطبيق: حين يكتمل صوت نُبلَّغ هنا
    AdhanAudioCacheManager.instance.onSoundReady = _onSoundDownloaded;
  }
  static final AdhanService instance = AdhanService._();

  static const MethodChannel _customNotificationChannel = MethodChannel(
    'com.masjed.mihrab/custom_prayer_notification',
  );

  // Audio Player for Preview & Live Adhan (lazily initialized)
  AudioPlayer? _playerInstance;
  AudioPlayer get _player {
    if (_playerInstance == null) {
      final p = AudioPlayer();
      if (!kIsWeb) {
        unawaited(
          p
              .setAudioContext(AudioContextConfig(stayAwake: true).build())
              .catchError((_) {}),
        );
      }

      // خطأ من المشغّل (ملف تالف مثلاً) ينهي التشغيل بهدوء بدل أن يبقى الزر يدور
      void onError(Object error) {
        debugPrint('⚠️ [AdhanService] player error: $error');
        _onPlaybackFinished();
      }

      p.onPlayerStateChanged.listen((state) {
        final isPlaying = state == PlayerState.playing;
        isPlayingNotifier.value = isPlaying;
        if (state == PlayerState.playing) {
          isBufferingNotifier.value = false;
        } else if (state == PlayerState.completed) {
          _onPlaybackFinished();
        }
      }, onError: onError);

      p.onPlayerComplete.listen((_) {
        _onPlaybackFinished();
      }, onError: onError);

      p.onPositionChanged.listen((pos) {
        positionNotifier.value = pos;
        if (pos > Duration.zero) {
          isBufferingNotifier.value = false;
        }
      }, onError: onError);

      p.onDurationChanged.listen((dur) {
        durationNotifier.value = dur;
        isBufferingNotifier.value = false;
      }, onError: onError);

      _playerInstance = p;
    }
    return _playerInstance!;
  }

  // أوامر المشغّل تُنفَّذ واحداً بعد الآخر: ضغطات متلاحقة (معاينة ثم أخرى ثم إيقاف)
  // كانت تتداخل داخل المشغّل، ومشغّل ويندوز يحمّل كل مصدر في خيط مستقل بلا قفل.
  Future<void> _playerChain = Future<void>.value();

  /// يزيد مع كل طلب تشغيل أو إيقاف: طلب سبقه أحدث منه لا يُنفَّذ.
  int _playRequest = 0;

  Future<void> _serial(Future<void> Function() command) {
    final next = _playerChain.then((_) => command()).catchError((Object e) {
      debugPrint('⚠️ [AdhanService] player command failed: $e');
    });
    _playerChain = next;
    return next;
  }

  Future<void> _stopPlayer() {
    _playRequest++;
    return _serial(() async => _playerInstance?.stop());
  }

  void _onPlaybackFinished() {
    isPlayingNotifier.value = false;
    isBufferingNotifier.value = false;
    currentPlayingSoundNotifier.value = null;
    liveFiringPrayerNotifier.value = null;
    positionNotifier.value = Duration.zero;
    BackgroundAudio.release(this);
    unawaited(refreshStickyNotification());
  }

  // Notifiers
  final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<AdhanSound> selectedSoundNotifier =
      ValueNotifier<AdhanSound>(AdhanData.defaultSound);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<AdhanSound?> currentPlayingSoundNotifier =
      ValueNotifier<AdhanSound?>(null);

  // Live Firing Alert (prayer name currently sounding, or null)
  final ValueNotifier<String?> liveFiringPrayerNotifier =
      ValueNotifier<String?>(null);

  bool get isLiveFiring => liveFiringPrayerNotifier.value != null;
  bool get isPlaying => isPlayingNotifier.value;

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

  // Active Location Coordinates & Metadata (default Damascus, Syria)
  double _latitude = 33.5138;
  double _longitude = 36.2765;
  String _cityName = 'دمشق، سوريا';
  bool _isGpsLocation = false;
  CalculationMethod _calculationMethod = CalculationMethod.muslim_world_league;
  Madhab _madhab = Madhab.shafi;
  final Map<String, int> _manualAdjustments = {
    'الفجر': 0,
    'الشروق': 0,
    'الظهر': 0,
    'العصر': 0,
    'المغرب': 0,
    'العشاء': 0,
  };

  // Notifiers for settings
  final ValueNotifier<String> cityNameNotifier = ValueNotifier<String>(
    'دمشق، سوريا',
  );
  final ValueNotifier<bool> isGpsLocationNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<CalculationMethod> calculationMethodNotifier =
      ValueNotifier<CalculationMethod>(CalculationMethod.muslim_world_league);
  final ValueNotifier<Madhab> madhabNotifier = ValueNotifier<Madhab>(
    Madhab.shafi,
  );
  final ValueNotifier<Map<String, int>> manualAdjustmentsNotifier =
      ValueNotifier<Map<String, int>>({
        'الفجر': 0,
        'الشروق': 0,
        'الظهر': 0,
        'العصر': 0,
        'المغرب': 0,
        'العشاء': 0,
      });

  Timer? _tickerTimer;
  String? _lastFiredPrayerKey;
  int _notificationTickCounter = 0;
  PrayerCountdownPhase? _lastPhase;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Pre-initialize offline audio cache manager
    await AdhanAudioCacheManager.instance.init();

    // Pre-initialize player
    _player;

    // Load persisted settings
    await _loadSettings();
    unawaited(refreshStickyNotification());
    unawaited(rescheduleNativeAlarms());

    if (!kIsWeb && _isGpsLocation) {
      unawaited(_tryBackgroundGpsRefresh());
    }

    // Register hardware volume keys handler (Volume Down / Mute silences Adhan immediately)
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
      _startTicker();
    }
  }

  Future<void> _tryBackgroundGpsRefresh() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final dist = Geolocator.distanceBetween(
        _latitude,
        _longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist > 2000) {
        await setLocationToGps(position: pos);
      }
    } catch (_) {}
  }

  /// Native Android actions (Silence, Live firing start, Completion). The channel is
  /// shared with [AppNotificationService], which owns its handler and forwards here.
  Future<void> handleNativeCall(MethodCall call) async {
    if (call.method == 'silenceAdhan') {
      await silenceAdhan();
    } else if (call.method == 'onAdhanStarted') {
      final prayerName = call.arguments as String? ?? 'الصلاة';
      // The native player is sounding the adhan: a preview must not play over it
      await _stopPlayer();
      currentPlayingSoundNotifier.value = null;
      liveFiringPrayerNotifier.value = prayerName;
      isPlayingNotifier.value = true;
      unawaited(refreshStickyNotification());
    } else if (call.method == 'onAdhanCompleted') {
      _onPlaybackFinished();
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    // الأذان يصدح الآن: أي زر صوت (رفع، خفض، كتم) يُسكته فوراً، كالمكالمة الواردة.
    // زر التشغيل والتطبيق مغلق يلتقطهما أندرويد نفسه (AdhanSilenceKeys).
    if (liveFiringPrayerNotifier.value != null &&
        (key == LogicalKeyboardKey.audioVolumeUp ||
            key == LogicalKeyboardKey.audioVolumeDown ||
            key == LogicalKeyboardKey.audioVolumeMute)) {
      silenceAdhan();
      return true; // consumed
    }

    // معاينة صوت: الخفض والكتم يوقفانها، والرفع يرفع الصوت كالمعتاد
    if (isPlayingNotifier.value &&
        (key == LogicalKeyboardKey.audioVolumeDown ||
            key == LogicalKeyboardKey.audioVolumeMute)) {
      silenceAdhan();
      return true;
    }
    return false;
  }

  Future<bool> setLocationToGps({Position? position}) async {
    try {
      Position? pos = position;
      if (pos == null) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return false;
        }
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
      }

      _latitude = pos.latitude;
      _longitude = pos.longitude;
      _isGpsLocation = true;

      // Find nearest city from catalog for readable location badge
      final nearest = PrayerCitiesData.findNearestCity(
        pos.latitude,
        pos.longitude,
      );
      if (nearest != null && nearest.$2 <= 60.0) {
        _cityName = '${nearest.$1.nameAr} (GPS)';
      } else if (nearest != null) {
        _cityName = 'موقعي الحالي (قرب ${nearest.$1.nameAr})';
      } else {
        _cityName = 'موقعي الحالي (GPS)';
      }

      cityNameNotifier.value = _cityName;
      isGpsLocationNotifier.value = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('adhan_latitude', _latitude);
      await prefs.setDouble('adhan_longitude', _longitude);
      await prefs.setString('adhan_city_name', _cityName);
      await prefs.setBool('adhan_is_gps', true);

      await refreshStickyNotification(force: true);
      await rescheduleNativeAlarms();
      return true;
    } catch (e) {
      debugPrint('⚠️ [AdhanService] Error updating location via GPS: $e');
      return false;
    }
  }

  Future<void> setCity(PrayerCity city) async {
    _latitude = city.latitude;
    _longitude = city.longitude;
    _cityName = city.displayName;
    _isGpsLocation = false;
    _calculationMethod = city.defaultMethod;

    cityNameNotifier.value = _cityName;
    isGpsLocationNotifier.value = false;
    calculationMethodNotifier.value = _calculationMethod;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('adhan_latitude', _latitude);
    await prefs.setDouble('adhan_longitude', _longitude);
    await prefs.setString('adhan_city_name', _cityName);
    await prefs.setBool('adhan_is_gps', false);
    await prefs.setString('adhan_calculation_method', _calculationMethod.name);

    await refreshStickyNotification(force: true);
    await rescheduleNativeAlarms();
  }

  Future<void> setCalculationMethod(CalculationMethod method) async {
    _calculationMethod = method;
    calculationMethodNotifier.value = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhan_calculation_method', method.name);

    await refreshStickyNotification(force: true);
    await rescheduleNativeAlarms();
  }

  Future<void> setMadhab(Madhab madhab) async {
    _madhab = madhab;
    madhabNotifier.value = madhab;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhan_madhab', madhab.name);

    await refreshStickyNotification(force: true);
    await rescheduleNativeAlarms();
  }

  Future<void> setPrayerAdjustment(String prayerName, int minutes) async {
    _manualAdjustments[prayerName] = minutes.clamp(-30, 30);
    manualAdjustmentsNotifier.value = Map<String, int>.from(_manualAdjustments);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'adhan_adj_$prayerName',
      _manualAdjustments[prayerName]!,
    );

    await refreshStickyNotification(force: true);
    await rescheduleNativeAlarms();
  }

  Future<void> resetAdjustments() async {
    for (final p in ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
      _manualAdjustments[p] = 0;
    }
    manualAdjustmentsNotifier.value = Map<String, int>.from(_manualAdjustments);
    final prefs = await SharedPreferences.getInstance();
    for (final p in ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
      await prefs.remove('adhan_adj_$p');
    }

    await refreshStickyNotification(force: true);
    await rescheduleNativeAlarms();
  }

  void updateLocation(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    final nearest = PrayerCitiesData.findNearestCity(lat, lng);
    if (nearest != null && nearest.$2 <= 60.0) {
      _cityName = '${nearest.$1.nameAr} (GPS)';
    } else {
      _cityName = 'موقعي الحالي (GPS)';
    }
    _isGpsLocation = true;
    cityNameNotifier.value = _cityName;
    isGpsLocationNotifier.value = true;
    unawaited(_saveLocation());
    unawaited(refreshStickyNotification(force: true));
    unawaited(rescheduleNativeAlarms());
  }

  // Kept for the next launch: alarms are set at startup, before any GPS fix
  Future<void> _saveLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('adhan_latitude', _latitude);
      await prefs.setDouble('adhan_longitude', _longitude);
      await prefs.setString('adhan_city_name', _cityName);
      await prefs.setBool('adhan_is_gps', _isGpsLocation);
    } catch (_) {}
  }

  double get latitude => _latitude;
  double get longitude => _longitude;
  String get cityName => _cityName;
  bool get isGpsLocation => _isGpsLocation;
  CalculationMethod get calculationMethod => _calculationMethod;
  Madhab get madhab => _madhab;
  Map<String, int> get manualAdjustments =>
      Map.unmodifiable(_manualAdjustments);

  bool isPrayerAdhanEnabled(String prayerName) {
    return _prayerEnabledMap[prayerName] ?? true;
  }

  Future<void> setPrayerAdhanEnabled(String prayerName, bool enabled) async {
    _prayerEnabledMap[prayerName] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_prayer_$prayerName', enabled);
    unawaited(rescheduleNativeAlarms());
  }

  int getIqamaMinutes(String prayerName) {
    return _iqamaMinutesMap[prayerName] ?? 15;
  }

  Future<void> setIqamaMinutes(String prayerName, int minutes) async {
    _iqamaMinutesMap[prayerName] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('iqama_min_$prayerName', minutes);
    unawaited(refreshStickyNotification());
  }

  Future<void> setVolume(double vol) async {
    final oldVol = _volume;
    _volume = vol.clamp(0.0, 1.0);
    try {
      if (_playerInstance != null) {
        await _playerInstance!.setVolume(_volume);
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('adhan_volume', _volume);

    // If Adhan is currently firing or playing, and user reduced the volume or muted it -> silence immediately!
    if ((liveFiringPrayerNotifier.value != null || isPlayingNotifier.value) &&
        (_volume == 0.0 || _volume < oldVol)) {
      await silenceAdhan();
    }
  }

  /// Silences the Adhan immediately across Flutter player and native Android player
  Future<void> silenceAdhan() async {
    liveFiringPrayerNotifier.value = null;
    isPlayingNotifier.value = false;
    currentPlayingSoundNotifier.value = null;
    positionNotifier.value = Duration.zero;
    await stop();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _customNotificationChannel.invokeMethod('silenceNativeAdhan');
      } catch (_) {}
    }
    unawaited(refreshStickyNotification());
  }

  Future<void> setSelectedSound(AdhanSound sound) async {
    selectedSoundNotifier.value = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhan_selected_sound_id', sound.id);
    if (prefs.getString(AdhanAudioCacheManager.pendingTargetPrefKey) ==
        sound.id) {
      await prefs.remove(AdhanAudioCacheManager.pendingTargetPrefKey);
    }
    await _storeNativeSoundPaths(prefs);

    unawaited(refreshStickyNotification());
    unawaited(rescheduleNativeAlarms());
  }

  /// مسارا الملفين اللذين يشغّلهما أندرويد عند الأذان: العادي لكل الصلوات، والفجر
  /// («الصلاة خير من النوم») للفجر وحده. بلا مسار يُؤذَّن بالأذان المضمَّن في التطبيق.
  Future<void> _storeNativeSoundPaths(SharedPreferences prefs) async {
    final cache = AdhanAudioCacheManager.instance;
    final sound = selectedSoundNotifier.value;
    for (final (key, path) in [
      ('adhan_sound_regular_path', cache.nativePath(sound, fajr: false)),
      ('adhan_sound_fajr_path', cache.nativePath(sound, fajr: true)),
    ]) {
      if (path != null) {
        await prefs.setString(key, path);
      } else {
        await prefs.remove(key);
      }
    }
    // مفتاح ما قبل 1.0.11: ملف واحد لكل الصلوات
    await prefs.remove('adhan_selected_sound_path');
  }

  /// اكتمل تنزيل صوت: إن كان هو الذي اختاره المستخدم وينتظر تنزيله صار صوت
  /// الأذان، وإن كان الصوت الحالي (ترقية تسجيله القديم) تُحدَّث مساراته.
  Future<void> _onSoundDownloaded(String soundId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(AdhanAudioCacheManager.pendingTargetPrefKey) ==
          soundId) {
        await setSelectedSound(AdhanData.getById(soundId));
      } else if (selectedSoundNotifier.value.id == soundId) {
        await _storeNativeSoundPaths(prefs);
      }
    } catch (e) {
      debugPrint('⚠️ [AdhanService] applying downloaded sound failed: $e');
    }
  }

  Future<void> setAdhanEnabled(bool enabled) async {
    isEnabledNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_master_enabled', enabled);
    unawaited(refreshStickyNotification());
    unawaited(rescheduleNativeAlarms());
  }

  /// Upcoming adhan times of the enabled prayers for the coming [days], in order.
  /// Android keeps this schedule and renews its own alarms from it after every adhan,
  /// so the adhan keeps sounding for days without the app being opened.
  List<Map<String, dynamic>> buildNativeAlarmSchedule({int days = 14}) {
    final now = DateTime.now();
    final alarms = <Map<String, dynamic>>[];
    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      for (final p in calculateTodaySchedule(forDate: day)) {
        final name = p['name'] as String;
        if (name == 'الشروق' || !isPrayerAdhanEnabled(name)) continue;
        final time = p['time'] as DateTime;
        if (time.isAfter(now)) {
          alarms.add({'name': name, 'time': time.millisecondsSinceEpoch});
        }
      }
    }
    return alarms;
  }

  /// Synchronizes calculated upcoming prayer times with Android AlarmManager exact alarms
  Future<void> rescheduleNativeAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final activeAlarms = buildNativeAlarmSchedule();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'adhan_cached_schedule_json',
        jsonEncode(activeAlarms),
      );

      if (isEnabledNotifier.value) {
        await _customNotificationChannel.invokeMethod(
          'schedulePrayerAlarms',
          activeAlarms,
        );
        debugPrint(
          '⏰ [AdhanService] Synced ${activeAlarms.length} exact alarms with Android AlarmManager',
        );
      } else {
        await _customNotificationChannel.invokeMethod('cancelPrayerAlarms');
        debugPrint(
          '🚫 [AdhanService] Master adhan disabled, cancelled native alarms',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [AdhanService] Error syncing native alarms: $e');
    }
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
      batteryIgnored =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
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
    final isCurrent =
        currentPlayingSoundNotifier.value?.id == sound.id &&
        liveFiringPrayerNotifier.value == null;

    // If clicking on current playing sound, toggle pause
    if (isCurrent && isPlayingNotifier.value) {
      isPlayingNotifier.value = false;
      return _serial(() async => _playerInstance?.pause());
    }

    // ما زال يبدأ: ضغطة ثانية لا تعيد تحميله
    if (isCurrent && isBufferingNotifier.value) return;

    // If clicking on paused sound, resume
    if (isCurrent && positionNotifier.value > Duration.zero) {
      isPlayingNotifier.value = true;
      return _serial(() async => _playerInstance?.resume());
    }

    final request = ++_playRequest;
    currentPlayingSoundNotifier.value = sound;
    isBufferingNotifier.value = true;
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration(seconds: sound.durationSeconds);

    return _serial(() async {
      if (request != _playRequest) return;
      try {
        // Stop only the local player — do NOT touch BackgroundAudio so we
        // don't kick out the Quran reciter or register a foreground media
        // session for a simple preview clip.
        await _player.stop();
        await _player.setVolume(_volume);
        // في المتصفح الصوت المختار يُبثّ كاملاً؛ ما عداه معاينة قصيرة مضمَّنة
        final cache = AdhanAudioCacheManager.instance;
        final source = kIsWeb && sound.id == selectedSoundNotifier.value.id
            ? (cache.sourceFor(sound) ?? cache.previewSource(sound))
            : cache.previewSource(sound);
        await _player.play(source).timeout(const Duration(seconds: 25));
        // Preview intentionally has NO BackgroundAudio.claim → stops when
        // the user leaves the app (correct behaviour for a preview clip).
        // Only the live Adhan fires with BackgroundAudio so it can continue
        // in the background.
      } catch (e) {
        debugPrint('⚠️ Error in AdhanService.playPreview: $e');
        if (request == _playRequest) _onPlaybackFinished();
      }
    });
  }

  /// «الصلاة خير من النوم» تُقال في أذان الفجر وحده.
  static bool isFajrPrayer(String prayerName) => prayerName.startsWith('الفجر');

  Future<void> playLiveAdhan(String prayerName) async {
    final sound = selectedSoundNotifier.value;
    final request = ++_playRequest;
    liveFiringPrayerNotifier.value = prayerName;
    currentPlayingSoundNotifier.value = sound;
    isBufferingNotifier.value = true;
    isPlayingNotifier.value = false;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration(seconds: sound.durationSeconds);

    return _serial(() async {
      if (request != _playRequest) return;
      try {
        await _player.stop();
        await _player.setVolume(_volume);
        final cache = AdhanAudioCacheManager.instance;
        final fajr = isFajrPrayer(prayerName);
        // الصوت المختار إن كان على الجهاز، وإلا الأذان المضمَّن: الأذان لا يفوت
        final source =
            cache.sourceFor(sound, fajr: fajr) ??
            cache.sourceFor(AdhanData.defaultSound, fajr: fajr)!;
        await _player.play(source).timeout(const Duration(seconds: 25));

        try {
          unawaited(BackgroundAudio.claim(this));
        } catch (_) {}
        _publishMediaSession(sound, isLive: true, prayerName: prayerName);
        unawaited(refreshStickyNotification());
      } catch (e) {
        debugPrint('⚠️ Error in AdhanService.playLiveAdhan: $e');
        if (request == _playRequest) _onPlaybackFinished();
      }
    });
  }

  @override
  Future<void> play() => resume();

  @override
  Future<void> pause() async {
    try {
      await _serial(() async => _playerInstance?.pause());
      isPlayingNotifier.value = false;
      final sound = currentPlayingSoundNotifier.value;
      if (sound != null) {
        BackgroundAudio.publish(
          this,
          item: _buildMediaItem(
            sound,
            isLive: liveFiringPrayerNotifier.value != null,
            prayerName: liveFiringPrayerNotifier.value,
          ),
          playing: false,
          buffering: false,
          position: positionNotifier.value,
        );
      }
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _serial(() async => _playerInstance?.resume());
      isPlayingNotifier.value = true;
      final sound = currentPlayingSoundNotifier.value;
      if (sound != null) {
        _publishMediaSession(
          sound,
          isLive: liveFiringPrayerNotifier.value != null,
          prayerName: liveFiringPrayerNotifier.value,
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    await _stopPlayer();
    _onPlaybackFinished();
  }

  @override
  Future<void> seek(Duration pos) async {
    try {
      await _serial(() async => _playerInstance?.seek(pos));
      positionNotifier.value = pos;
    } catch (_) {}
  }

  @override
  Future<void> skipToNext() => Future.value();

  @override
  Future<void> skipToPrevious() => Future.value();

  MediaItem _buildMediaItem(
    AdhanSound sound, {
    bool isLive = false,
    String? prayerName,
  }) {
    return MediaItem(
      id: sound.id,
      title: isLive && prayerName != null ? 'أذان $prayerName' : sound.title,
      artist: sound.muezzinOrLocation,
      album: 'تطبيق محراب - الأذان الشريف',
      duration: Duration(seconds: sound.durationSeconds),
    );
  }

  void _publishMediaSession(
    AdhanSound sound, {
    bool isLive = false,
    String? prayerName,
  }) {
    BackgroundAudio.publish(
      this,
      item: _buildMediaItem(sound, isLive: isLive, prayerName: prayerName),
      playing: isPlayingNotifier.value,
      buffering: isBufferingNotifier.value,
      position: positionNotifier.value,
      seekable: false,
    );
  }

  @override
  void syncMediaSession() {
    final sound = currentPlayingSoundNotifier.value;
    if (sound != null) {
      _publishMediaSession(
        sound,
        isLive: liveFiringPrayerNotifier.value != null,
        prayerName: liveFiringPrayerNotifier.value,
      );
    }
  }

  // --- Live Calculations & Iqama Tracking ---

  List<Map<String, dynamic>> calculateTodaySchedule({DateTime? forDate}) {
    final now = forDate ?? DateTime.now();
    final coords = Coordinates(_latitude, _longitude);
    final params = _calculationMethod.getParameters();
    params.madhab = _madhab;
    params.adjustments = PrayerAdjustments(
      fajr: _manualAdjustments['الفجر'] ?? 0,
      sunrise: _manualAdjustments['الشروق'] ?? 0,
      dhuhr: _manualAdjustments['الظهر'] ?? 0,
      asr: _manualAdjustments['العصر'] ?? 0,
      maghrib: _manualAdjustments['المغرب'] ?? 0,
      isha: _manualAdjustments['العشاء'] ?? 0,
    );

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
      final adjFajr = _manualAdjustments['الفجر'] ?? 0;
      final adjSunrise = _manualAdjustments['الشروق'] ?? 0;
      final adjDhuhr = _manualAdjustments['الظهر'] ?? 0;
      final adjAsr = _manualAdjustments['العصر'] ?? 0;
      final adjMaghrib = _manualAdjustments['المغرب'] ?? 0;
      final adjIsha = _manualAdjustments['العشاء'] ?? 0;
      return [
        {
          'name': 'الفجر',
          'time': DateTime(y, m, d, 4, 42).add(Duration(minutes: adjFajr)),
          'iqamaMinutes': 25,
          'hasIqama': true,
        },
        {
          'name': 'الشروق',
          'time': DateTime(y, m, d, 6, 5).add(Duration(minutes: adjSunrise)),
          'iqamaMinutes': 0,
          'hasIqama': false,
        },
        {
          'name': 'الظهر',
          'time': DateTime(y, m, d, 12, 38).add(Duration(minutes: adjDhuhr)),
          'iqamaMinutes': 20,
          'hasIqama': true,
        },
        {
          'name': 'العصر',
          'time': DateTime(y, m, d, 16, 8).add(Duration(minutes: adjAsr)),
          'iqamaMinutes': 20,
          'hasIqama': true,
        },
        {
          'name': 'المغرب',
          'time': DateTime(y, m, d, 18, 55).add(Duration(minutes: adjMaghrib)),
          'iqamaMinutes': 10,
          'hasIqama': true,
        },
        {
          'name': 'العشاء',
          'time': DateTime(y, m, d, 20, 25).add(Duration(minutes: adjIsha)),
          'iqamaMinutes': 15,
          'hasIqama': true,
        },
      ];
    }
  }

  /// Evaluates current state: whether counting down to next Adhan or counting down to Iqama!
  ///
  /// [at] لحظة بديلة عن الساعة (للاختبار).
  CurrentPrayerState getCurrentPrayerState({DateTime? at}) {
    final now = at ?? DateTime.now();
    final todaySchedule = calculateTodaySchedule(forDate: now);

    // 1. Check if we are currently in an Iqama interval for any prayer!
    for (int i = 0; i < todaySchedule.length; i++) {
      final p = todaySchedule[i];
      final pTime = p['time'] as DateTime;
      final int iqamaMin = (p['iqamaMinutes'] as int?) ?? 0;
      final bool hasIqama = p['hasIqama'] == true && iqamaMin > 0;

      if (hasIqama) {
        final iqamaTime = pTime.add(Duration(minutes: iqamaMin));
        // من لحظة دخول الوقت نفسها (لا بعدها بجزء من الثانية) حتى الإقامة: عدّاد الإقامة
        if (!now.isBefore(pTime) && now.isBefore(iqamaTime)) {
          final rawRemaining = iqamaTime.difference(now);
          // Clamp to zero — avoids negative display if system clock ticks
          // past the target between UI frames.
          final remainingToIqama = rawRemaining.isNegative
              ? Duration.zero
              : rawRemaining;
          // Next prayer will be the one after this
          String nextPName = 'الشروق';
          DateTime nextPTime = todaySchedule[1]['time'] as DateTime;
          if (i + 1 < todaySchedule.length) {
            nextPName = todaySchedule[i + 1]['name'] as String;
            nextPTime = todaySchedule[i + 1]['time'] as DateTime;
          } else {
            // Tomorrow's Fajr
            final tomSchedule = calculateTodaySchedule(
              forDate: now.add(const Duration(days: 1)),
            );
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

    // 2. Otherwise we are counting down to the upcoming prayer Adhan.
    //    Skip prayers whose Iqama window has already passed so we never
    //    show a negative countdown for a prayer that ended moments ago.
    for (int i = 0; i < todaySchedule.length; i++) {
      final p = todaySchedule[i];
      final pTime = p['time'] as DateTime;
      if (pTime.isAfter(now)) {
        final rawRemaining = pTime.difference(now);
        return CurrentPrayerState(
          prayerName: p['name'] as String,
          prayerTime: pTime,
          phase: PrayerCountdownPhase.beforeAdhan,
          remaining: rawRemaining.isNegative ? Duration.zero : rawRemaining,
          nextPrayerName: p['name'] as String,
          nextPrayerTime: pTime,
        );
      }
    }

    // 3. Past Isha → Tomorrow's Fajr
    final tomSchedule = calculateTodaySchedule(
      forDate: now.add(const Duration(days: 1)),
    );
    final tomorrowFajr = tomSchedule.first['time'] as DateTime;
    final rawRemaining = tomorrowFajr.difference(now);
    return CurrentPrayerState(
      prayerName: 'الفجر (غداً)',
      prayerTime: tomorrowFajr,
      phase: PrayerCountdownPhase.beforeAdhan,
      remaining: rawRemaining.isNegative ? Duration.zero : rawRemaining,
      nextPrayerName: 'الفجر (غداً)',
      nextPrayerTime: tomorrowFajr,
    );
  }

  /// مواقيت الأيام القادمة لشريط الإشعار: لكل حدث لحظة الأذان، ولحظة الإقامة (0 للشروق).
  List<Map<String, dynamic>> buildNotificationTimeline({int days = 14}) {
    final now = DateTime.now();
    final timeline = <Map<String, dynamic>>[];
    for (var d = 0; d < days; d++) {
      // DateTime(y, m, d + n) لا Duration(days: n): يبقى منتصف الليل صحيحاً عند تغيّر التوقيت الصيفي
      final day = DateTime(now.year, now.month, now.day + d);
      for (final p in calculateTodaySchedule(forDate: day)) {
        final adhan = p['time'] as DateTime;
        final iqamaMinutes = (p['iqamaMinutes'] as int?) ?? 0;
        final hasIqama = p['hasIqama'] == true && iqamaMinutes > 0;
        timeline.add({
          'name': p['name'],
          'adhan': adhan.millisecondsSinceEpoch,
          'iqama': hasIqama
              ? adhan
                    .add(Duration(minutes: iqamaMinutes))
                    .millisecondsSinceEpoch
              : 0,
        });
      }
    }
    return timeline;
  }

  /// سماء الأيام نفسها لشريط الإشعار: منها يرسم أندرويد الشمس والقمر والتطبيق مغلق.
  /// تبدأ من أمس كي يُعرف طلوع قمرٍ هو فوق الأفق الآن.
  Map<String, dynamic> buildNotificationSky({int days = 14}) {
    final now = DateTime.now();
    return SkyTrack.build(
      from: DateTime(now.year, now.month, now.day - 1),
      to: DateTime(now.year, now.month, now.day + days),
      latitude: _latitude,
      longitude: _longitude,
    );
  }

  String? _stickySignature;

  /// يرسل جدول الأسبوعين القادمين إلى شريط الإشعار الدائم. الشريط في أندرويد يعدّ وينتقل
  /// بين الأذان والإقامة وحده، فلا يُعاد الإرسال إلا حين يتغيّر شيء: اليوم، الموقع، الإقامة.
  Future<void> refreshStickyNotification({bool force = false}) async {
    try {
      final now = DateTime.now();
      final signature =
          '${now.year}-${now.month}-${now.day}|$_latitude|$_longitude|$_iqamaMinutesMap|${_calculationMethod.name}|${_madhab.name}|$_manualAdjustments';
      if (!force && signature == _stickySignature) return;
      final sent = await AppNotificationService.instance
          .syncStickyPrayerNotification(
            buildNotificationTimeline(),
            sky: buildNotificationSky(),
          );
      if (sent) _stickySignature = signature;
    } catch (_) {}
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkPrayerArrival();

      _notificationTickCounter++;
      final currentState = getCurrentPrayerState();
      if (_lastPhase != currentState.phase || _notificationTickCounter >= 30) {
        _lastPhase = currentState.phase;
        _notificationTickCounter = 0;
        unawaited(refreshStickyNotification());
      }
    });
  }

  void stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  void _checkPrayerArrival() {
    if (liveFiringPrayerNotifier.value != null) return;
    final now = DateTime.now();
    final todaySchedule = calculateTodaySchedule(forDate: now);

    for (final p in todaySchedule) {
      final pName = p['name'] as String;
      // Sunrise is not a prayer with Adhan
      if (pName == 'الشروق') continue;

      final pTime = p['time'] as DateTime;
      final diff = now.difference(pTime);

      // Check if prayer time arrived in the last 15 seconds (wider window for foreground apps)
      if (diff.inSeconds >= 0 && diff.inSeconds <= 15) {
        final key = '${now.year}-${now.month}-${now.day}_$pName';
        if (_lastFiredPrayerKey != key) {
          _lastFiredPrayerKey = key;
          _onAdhanTimeReached(pName, pTime);
        }
      }
    }
  }

  void _onAdhanTimeReached(String prayerName, DateTime prayerTime) {
    if (!isEnabledNotifier.value) return;
    if (!isPrayerAdhanEnabled(prayerName)) return;

    // Android sounds the adhan from its own service, the one the exact alarm starts.
    // It ignores this request when the alarm got there first, so the adhan plays once.
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(_startNativeAdhan(prayerName, prayerTime));
      return;
    }

    playLiveAdhan(prayerName);
  }

  Future<void> _startNativeAdhan(String prayerName, DateTime prayerTime) async {
    try {
      await _customNotificationChannel.invokeMethod('startAdhanNow', {
        'name': prayerName,
        'time': prayerTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('⚠️ [AdhanService] Error starting native adhan: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isEnabledNotifier.value = prefs.getBool('adhan_master_enabled') ?? false;

      final cache = AdhanAudioCacheManager.instance;
      var soundId = prefs.getString('adhan_selected_sound_id');
      // صوت اختاره المستخدم واكتمل تنزيله والتطبيق يُغلق: يُعتمد الآن
      final pending = prefs.getString(
        AdhanAudioCacheManager.pendingTargetPrefKey,
      );
      if (pending != null &&
          pending != soundId &&
          cache.sourceFor(AdhanData.getById(pending)) != null) {
        soundId = pending;
        await prefs.setString('adhan_selected_sound_id', pending);
        await prefs.remove(AdhanAudioCacheManager.pendingTargetPrefKey);
      }
      selectedSoundNotifier.value = AdhanData.getById(soundId);

      // Ensure local audio file paths are stored for Android native player
      if (!kIsWeb) await _storeNativeSoundPaths(prefs);

      _volume = prefs.getDouble('adhan_volume') ?? 1.0;
      _latitude = prefs.getDouble('adhan_latitude') ?? _latitude;
      _longitude = prefs.getDouble('adhan_longitude') ?? _longitude;
      _cityName = prefs.getString('adhan_city_name') ?? 'دمشق، سوريا';
      _isGpsLocation = prefs.getBool('adhan_is_gps') ?? false;
      cityNameNotifier.value = _cityName;
      isGpsLocationNotifier.value = _isGpsLocation;

      final methodStr = prefs.getString('adhan_calculation_method');
      if (methodStr != null) {
        _calculationMethod = CalculationMethod.values.firstWhere(
          (m) => m.name == methodStr,
          orElse: () => CalculationMethod.muslim_world_league,
        );
      }
      calculationMethodNotifier.value = _calculationMethod;

      final madhabStr = prefs.getString('adhan_madhab');
      if (madhabStr != null) {
        _madhab = Madhab.values.firstWhere(
          (m) => m.name == madhabStr,
          orElse: () => Madhab.shafi,
        );
      }
      madhabNotifier.value = _madhab;

      for (final p in [
        'الفجر',
        'الشروق',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
      ]) {
        final adj = prefs.getInt('adhan_adj_$p');
        if (adj != null) {
          _manualAdjustments[p] = adj;
        }
      }
      manualAdjustmentsNotifier.value = Map<String, int>.from(
        _manualAdjustments,
      );

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
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    _tickerTimer?.cancel();
    _tickerTimer = null;
    try {
      _playerInstance?.dispose();
      _playerInstance = null;
    } catch (_) {}
    BackgroundAudio.release(this);
    _initialized = false;
  }
}
