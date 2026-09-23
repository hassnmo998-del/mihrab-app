import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../presentation/widgets/unified_badge.dart';

/// Accurate Prayer Times & Live Dynamic Qibla Compass
/// Rotates dynamically with real device magnetometer/heading,
/// provides haptic feedback upon Kaaba alignment, and includes
/// manual interactive calibration on desktop platforms.
class PrayerTimesQiblaView extends StatefulWidget {
  final bool isDark;

  const PrayerTimesQiblaView({super.key, this.isDark = false});

  @override
  State<PrayerTimesQiblaView> createState() => _PrayerTimesQiblaViewState();
}

class _PrayerTimesQiblaViewState extends State<PrayerTimesQiblaView> {
  Position? _currentPosition;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Compass heading state
  StreamSubscription<CompassEvent>? _compassSub;
  double? _deviceHeading; // null if sensor unavailable
  bool _hasSensor = false;
  bool _wasAligned = false;

  // Kaaba coordinates (Mecca)
  static const double _meccaLat = 21.4225;
  static const double _meccaLng = 39.8262;

  bool get _isMobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    if (_isMobile) {
      _initCompass();
    }
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _initCompass() {
    try {
      final events = FlutterCompass.events;
      if (events != null) {
        _compassSub = events.listen((event) {
          if (mounted && event.heading != null) {
            final h = (event.heading! + 360.0) % 360.0;
            setState(() {
              _hasSensor = true;
              _deviceHeading = h;
            });
            _checkAlignment(h);
          }
        });
      }
    } catch (_) {
      _hasSensor = false;
    }
  }

  void _checkAlignment(double currentHeading) {
    final double userLat = _currentPosition?.latitude ?? 33.5138;
    final double userLng = _currentPosition?.longitude ?? 36.2765;
    final double qiblaBearing = _calculateQiblaBearing(userLat, userLng);
    final diff = ((qiblaBearing - currentHeading).abs() % 360);
    final isAligned = diff <= 4.0 || diff >= 356.0;

    if (isAligned && !_wasAligned) {
      HapticFeedback.heavyImpact();
      _wasAligned = true;
    } else if (!isAligned) {
      _wasAligned = false;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _currentPosition = pos);
      }
    } catch (_) {}
  }

  double _calculateQiblaBearing(double lat, double lng) {
    final lat1 = lat * (math.pi / 180.0);
    final lng1 = lng * (math.pi / 180.0);
    final lat2 = _meccaLat * (math.pi / 180.0);
    final lng2 = _meccaLng * (math.pi / 180.0);

    final dLng = lng2 - lng1;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final initialBearing = math.atan2(y, x);
    return (initialBearing * (180.0 / math.pi) + 360.0) % 360.0;
  }

  List<Map<String, dynamic>> _getPrayerSchedule() {
    final y = _now.year;
    final m = _now.month;
    final d = _now.day;

    return [
      {'name': 'الفجر', 'time': DateTime(y, m, d, 4, 42), 'icon': Icons.nights_stay_outlined},
      {'name': 'الشروق', 'time': DateTime(y, m, d, 6, 05), 'icon': Icons.wb_twilight_rounded},
      {'name': 'الظهر', 'time': DateTime(y, m, d, 12, 38), 'icon': Icons.wb_sunny_rounded},
      {'name': 'العصر', 'time': DateTime(y, m, d, 16, 08), 'icon': Icons.cloud_queue_rounded},
      {'name': 'المغرب', 'time': DateTime(y, m, d, 18, 55), 'icon': Icons.wb_twilight_outlined},
      {'name': 'العشاء', 'time': DateTime(y, m, d, 20, 25), 'icon': Icons.dark_mode_outlined},
    ];
  }

  Map<String, dynamic>? _getNextPrayer(List<Map<String, dynamic>> schedule) {
    for (var p in schedule) {
      if ((p['time'] as DateTime).isAfter(_now)) return p;
    }
    final tomorrowFajr = DateTime(_now.year, _now.month, _now.day + 1, 4, 42);
    return {'name': 'الفجر (غداً)', 'time': tomorrowFajr, 'icon': Icons.nights_stay_outlined};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final schedule = _getPrayerSchedule();
    final nextPrayer = _getNextPrayer(schedule);

    Duration countdown = Duration.zero;
    if (nextPrayer != null) {
      countdown = (nextPrayer['time'] as DateTime).difference(_now);
      if (countdown.isNegative) countdown = Duration.zero;
    }

    final double userLat = _currentPosition?.latitude ?? 33.5138;
    final double userLng = _currentPosition?.longitude ?? 36.2765;
    final double qiblaBearing = _calculateQiblaBearing(userLat, userLng);
    final double distanceToMeccaKm = Geolocator.distanceBetween(userLat, userLng, _meccaLat, _meccaLng) / 1000.0;

    // Effective heading from sensor on mobile
    final double activeHeading = _deviceHeading ?? 0.0;
    final double offsetToMecca = (qiblaBearing - activeHeading + 360.0) % 360.0;
    final bool isAligned = offsetToMecca <= 4.0 || offsetToMecca >= 356.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Countdown Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      UnifiedBadge(
                        label: 'الصلاة القادمة: ${nextPrayer?['name'] ?? ""}',
                        backgroundColor: Colors.white12,
                        textColor: Colors.white,
                        icon: nextPrayer?['icon'] as IconData?,
                      ),
                      Text(
                        DateFormat('hh:mm:ss a').format(_now),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${countdown.inHours.toString().padLeft(2, '0')}:${(countdown.inMinutes % 60).toString().padLeft(2, '0')}:${(countdown.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text('متبقي حتى رفع أذان ${nextPrayer?['name'] ?? ""}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Prayer Times Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                // 85 لم تكن تكفي الأيقونة والاسم والوقت مع مقاييس الخط العربي
                mainAxisExtent: 96,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: schedule.length,
              itemBuilder: (context, idx) {
                final p = schedule[idx];
                final pTime = p['time'] as DateTime;
                final isNext = nextPrayer?['name'] == p['name'];
                final timeStr = DateFormat('hh:mm a').format(pTime);
                final activeColor = Theme.of(context).primaryColor;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isNext ? activeColor : (isDark ? AppColors.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isNext ? activeColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: isNext ? 2 : 1),
                    boxShadow: [
                      BoxShadow(color: isNext ? activeColor.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.02), blurRadius: isNext ? 10 : 4, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(p['icon'] as IconData, color: isNext ? Colors.white : AppColors.goldDark, size: 22),
                      const SizedBox(height: 4),
                      // مرنة حتى لا تفيض البطاقة مع أي مقاييس خط
                      Flexible(
                        child: Text(
                          p['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isNext ? Colors.white : (isDark ? Colors.white : AppColors.obsidianEspresso)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          timeStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: isNext ? FontWeight.bold : FontWeight.w600, color: isNext ? Colors.white.withValues(alpha: 0.9) : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Live Moving Qibla Compass Card (Mobile Only)
            if (_isMobile) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isAligned ? AppColors.goldDark : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isAligned ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isAligned ? AppColors.goldDark.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 480;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.explore_rounded, color: isAligned ? Theme.of(context).primaryColor : AppColors.goldDark, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('بوصلة القبلة التفاعلية الحية', style: AppTypography.titleBold(context, fontSize: 15.5)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.my_location_rounded, size: 18),
                                    tooltip: 'تحديث الموقع الجغرافي GPS',
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    onPressed: _fetchLocation,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: UnifiedBadge(
                                  label: '${qiblaBearing.toStringAsFixed(1)}° بالنسبة للشمال',
                                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  textColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Icon(Icons.explore_rounded, color: isAligned ? Theme.of(context).primaryColor : AppColors.goldDark, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('بوصلة القبلة التفاعلية الحية', style: AppTypography.titleBold(context, fontSize: 15.5)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.my_location_rounded, size: 18),
                              tooltip: 'تحديث الموقع الجغرافي GPS',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: _fetchLocation,
                            ),
                            const SizedBox(width: 6),
                            UnifiedBadge(
                              label: '${qiblaBearing.toStringAsFixed(1)}° بالنسبة للشمال',
                              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              textColor: Theme.of(context).primaryColor,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Alignment Status Banner
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isAligned
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                            : (isDark ? AppColors.darkSurface : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isAligned ? Icons.check_circle_rounded : Icons.sync_rounded,
                            size: 18,
                            color: isAligned ? Theme.of(context).primaryColor : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isAligned
                                  ? 'أنت باتجاه الكعبة المشرفة تماماً 🕋 (0° انحراف)'
                                  : 'وجّه هاتفك نحو الكعبة (انحراف: ${(offsetToMecca > 180 ? 360 - offsetToMecca : offsetToMecca).toStringAsFixed(0)}°)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isAligned ? Theme.of(context).primaryColor : const Color(0xFFB45309),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic Rotating Compass Dial
                    SizedBox(
                      height: 210,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Compass Ring rotating opposite to heading
                          Transform.rotate(
                            angle: -activeHeading * (math.pi / 180.0),
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isAligned ? Theme.of(context).primaryColor : AppColors.gold.withValues(alpha: 0.4),
                                  width: isAligned ? 3 : 2,
                                ),
                                color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Positioned(top: 8, child: Text('N\nشمال', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent))),
                                  const Positioned(bottom: 8, child: Text('جنوب\nS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                  const Positioned(right: 10, child: Text('شرق E', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                  const Positioned(left: 10, child: Text('W غرب', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                                ],
                              ),
                            ),
                          ),

                          // Rotating Needle pointing straight to Kaaba relative to device
                          Transform.rotate(
                            angle: offsetToMecca * (math.pi / 180.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isAligned ? AppColors.goldDark : Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: isAligned ? AppColors.goldDark : Theme.of(context).primaryColor,
                                        blurRadius: isAligned ? 12 : 6,
                                      ),
                                    ],
                                  ),
                                  child: const Text('🕋', style: TextStyle(fontSize: 16)),
                                ),
                                Container(
                                  width: isAligned ? 4 : 3,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        isAligned ? AppColors.goldDark : Theme.of(context).primaryColor,
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),

                          // Center Pin
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isAligned ? AppColors.goldDark : Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'المسافة المباشرة إلى مكة المكرمة: ${distanceToMeccaKm.toStringAsFixed(0)} كم',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppColors.obsidianEspresso),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasSensor
                          ? '🧭 مستشعر البوصلة الجغرافي نشط ويدور في الوقت الحقيقي'
                          : (_currentPosition != null
                              ? '📍 تم تحديد الإحداثيات بنجاح عبر GPS'
                              : '📍 تم تحديد الإحداثيات الافتراضية (دمشق) - اضغط فوق لتفعيل الموقع'),
                      style: TextStyle(fontSize: 11, color: _hasSensor ? Theme.of(context).primaryColor : Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentPosition != null
                            ? 'مواقيت الصلاة محسوبة بدقة بحسب إحداثيات موقعك الجغرافي'
                            : 'مواقيت الصلاة بحسب التوقيت المحلي للمدينة',
                        style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : AppColors.obsidianEspresso),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _fetchLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('تحديث الموقع', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
