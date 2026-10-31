import 'package:adhan/adhan.dart';
import 'package:flutter_app/models/prayer_calculation_settings.dart';
import 'package:flutter_app/services/adhan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'PrayerCitiesData contains curated cities and finds nearest city correctly',
    () {
      expect(PrayerCitiesData.allCities, isNotEmpty);
      expect(
        PrayerCitiesData.syrianCities.any((c) => c.nameAr == 'دمشق'),
        isTrue,
      );
      expect(
        PrayerCitiesData.syrianCities.any((c) => c.nameAr == 'حلب'),
        isTrue,
      );

      // Near Aleppo coordinates
      final nearestAleppo = PrayerCitiesData.findNearestCity(36.20, 37.13);
      expect(nearestAleppo, isNotNull);
      expect(nearestAleppo!.$1.nameAr, 'حلب');
      expect(nearestAleppo.$2, lessThan(10.0)); // within 10 km

      // Near Makkah coordinates
      final nearestMakkah = PrayerCitiesData.findNearestCity(21.42, 39.82);
      expect(nearestMakkah, isNotNull);
      expect(nearestMakkah!.$1.nameAr, 'مكة المكرمة');
      expect(nearestMakkah.$1.defaultMethod, CalculationMethod.umm_al_qura);
    },
  );

  test(
    'Setting city updates service coordinates, name and calculation method',
    () async {
      final service = AdhanService.instance;
      final aleppo = PrayerCitiesData.syrianCities.firstWhere(
        (c) => c.nameAr == 'حلب',
      );

      await service.setCity(aleppo);

      expect(service.latitude, aleppo.latitude);
      expect(service.longitude, aleppo.longitude);
      expect(service.cityName, aleppo.displayName);
      expect(service.isGpsLocation, isFalse);

      final makkah = PrayerCitiesData.saudiAndGulfCities.firstWhere(
        (c) => c.nameAr == 'مكة المكرمة',
      );
      await service.setCity(makkah);

      expect(service.latitude, makkah.latitude);
      expect(service.calculationMethod, CalculationMethod.umm_al_qura);
    },
  );

  test('Asr madhab toggle alters Asr prayer time properly', () async {
    final service = AdhanService.instance;
    final damascus = PrayerCitiesData.syrianCities.firstWhere(
      (c) => c.nameAr == 'دمشق',
    );
    await service.setCity(damascus);

    await service.setMadhab(Madhab.shafi);
    final shafiSchedule = service.calculateTodaySchedule();
    final shafiAsr =
        shafiSchedule.firstWhere((p) => p['name'] == 'العصر')['time']
            as DateTime;

    await service.setMadhab(Madhab.hanafi);
    final hanafiSchedule = service.calculateTodaySchedule();
    final hanafiAsr =
        hanafiSchedule.firstWhere((p) => p['name'] == 'العصر')['time']
            as DateTime;

    // Hanafi Asr starts later than Shafi Asr (around 30 to 70 minutes)
    expect(hanafiAsr.isAfter(shafiAsr), isTrue);
    expect(hanafiAsr.difference(shafiAsr).inMinutes, inInclusiveRange(30, 80));

    // Reset back
    await service.setMadhab(Madhab.shafi);
  });

  test(
    'Manual minute adjustments shift prayer times by exact offsets',
    () async {
      final service = AdhanService.instance;
      await service.resetAdjustments();

      final baseSchedule = service.calculateTodaySchedule();
      final baseFajr =
          baseSchedule.firstWhere((p) => p['name'] == 'الفجر')['time']
              as DateTime;
      final baseMaghrib =
          baseSchedule.firstWhere((p) => p['name'] == 'المغرب')['time']
              as DateTime;

      await service.setPrayerAdjustment('الفجر', 3);
      await service.setPrayerAdjustment('المغرب', -2);

      final adjustedSchedule = service.calculateTodaySchedule();
      final adjFajr =
          adjustedSchedule.firstWhere((p) => p['name'] == 'الفجر')['time']
              as DateTime;
      final adjMaghrib =
          adjustedSchedule.firstWhere((p) => p['name'] == 'المغرب')['time']
              as DateTime;

      expect(adjFajr.difference(baseFajr).inMinutes, 3);
      expect(adjMaghrib.difference(baseMaghrib).inMinutes, -2);

      await service.resetAdjustments();
      final resetSchedule = service.calculateTodaySchedule();
      final resetFajr =
          resetSchedule.firstWhere((p) => p['name'] == 'الفجر')['time']
              as DateTime;
      expect(resetFajr.difference(baseFajr).inMinutes, 0);
    },
  );
}
