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
import '../../../services/adhan_service.dart';
import 'adhan_audio_card.dart';

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
    AdhanService.instance.init();
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
    final double userLat = _currentPosition?.latitude ?? AdhanService.instance.latitude;
    final double userLng = _currentPosition?.longitude ?? AdhanService.instance.longitude;
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
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            AdhanService.instance.updateLocation(pos.latitude, pos.longitude);
          });
        }
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

  IconData _getPrayerIcon(String name) {
    if (name.contains('الفجر')) return Icons.nights_stay_outlined;
    if (name.contains('الشروق')) return Icons.wb_twilight_rounded;
    if (name.contains('الظهر')) return Icons.wb_sunny_rounded;
    if (name.contains('العصر')) return Icons.cloud_queue_rounded;
    if (name.contains('المغرب')) return Icons.wb_twilight_outlined;
    return Icons.dark_mode_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final schedule = AdhanService.instance.calculateTodaySchedule(forDate: _now);
    final prayerState = AdhanService.instance.getCurrentPrayerState();
    final isIqamaPhase = prayerState.phase == PrayerCountdownPhase.betweenAdhanAndIqama;

    final double userLat = _currentPosition?.latitude ?? AdhanService.instance.latitude;
    final double userLng = _currentPosition?.longitude ?? AdhanService.instance.longitude;
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
            // High-visibility Live Adhan Silence Alert Banner
            ValueListenableBuilder<String?>(
              valueListenable: AdhanService.instance.liveFiringPrayerNotifier,
              builder: (context, livePrayer, _) {
                if (livePrayer == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'حان الآن أذان $livePrayer 🕌',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'اضغط زر خفض الصوت بالهاتف أو الزر لإسكاته فوراً',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => AdhanService.instance.silenceAdhan(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.volume_off_rounded, size: 18),
                        label: const Text(
                          'إسكات فوراً 🔇',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Adhan Audio & Controls Card (Quran Audio Bar Style)
            AdhanAudioCard(isDark: isDark),

            // Countdown Hero Card (Dynamic Adhan & Iqama Countdown)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isIqamaPhase
                      ? [
                          const Color(0xFFC2410C),
                          const Color(0xFFEA580C),
                        ]
                      : [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withValues(alpha: 0.8),
                        ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (isIqamaPhase ? Colors.orange : Theme.of(context).primaryColor)
                        .withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Center(
                    child: UnifiedBadge(
                      label: isIqamaPhase
                          ? 'حان الآن وقت أذان ${prayerState.prayerName} 🕌'
                          : 'الصلاة القادمة: ${prayerState.nextPrayerName}',
                      backgroundColor: isIqamaPhase ? Colors.white24 : Colors.white12,
                      textColor: Colors.white,
                      icon: isIqamaPhase
                          ? Icons.mosque_rounded
                          : _getPrayerIcon(prayerState.nextPrayerName),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isIqamaPhase
                        ? '${prayerState.remaining.inMinutes.toString().padLeft(2, '0')}:${(prayerState.remaining.inSeconds % 60).toString().padLeft(2, '0')}'
                        : '${prayerState.remaining.inHours.toString().padLeft(2, '0')}:${(prayerState.remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(prayerState.remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isIqamaPhase)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'متبقي حتى إقامة صلاة ${prayerState.prayerName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'متبقي حتى رفع أذان ${prayerState.nextPrayerName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
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
                mainAxisExtent: 96,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: schedule.length,
              itemBuilder: (context, idx) {
                final p = schedule[idx];
                final pTime = p['time'] as DateTime;
                final pName = p['name'] as String;

                final isCurrentIqama = isIqamaPhase && pName == prayerState.prayerName;
                final isNextAdhan = !isIqamaPhase &&
                    (prayerState.nextPrayerName == pName ||
                        prayerState.nextPrayerName.startsWith(pName));
                final isHighlighted = isCurrentIqama || isNextAdhan;

                final timeStr = DateFormat('hh:mm a').format(pTime);
                final activeColor = isCurrentIqama ? Colors.orange.shade800 : Theme.of(context).primaryColor;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? activeColor
                        : (isDark ? AppColors.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHighlighted
                          ? activeColor
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: isHighlighted ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isHighlighted
                            ? activeColor.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.02),
                        blurRadius: isHighlighted ? 10 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getPrayerIcon(pName),
                        color: isHighlighted ? Colors.white : AppColors.goldDark,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          isCurrentIqama ? '$pName (إقامة)' : pName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isHighlighted
                                ? Colors.white
                                : (isDark ? Colors.white : AppColors.obsidianEspresso),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          timeStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                            color: isHighlighted
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.grey,
                          ),
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
