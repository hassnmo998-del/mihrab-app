import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/presentation/blocs/blocs.dart';
import 'package:flutter_app/screens/settings_screen.dart';
import 'package:flutter_app/services/data_service.dart';
import 'package:flutter_app/core/theme/app_colors.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initInjection();
  });

  group('SettingsScreen Redesign Tests', () {
    testWidgets('SettingsScreen renders correct order and no palette titles', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataService = sl<DataService>();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<ThemeCubit>(create: (_) => sl<ThemeCubit>()),
          ],
          child: ChangeNotifierProvider<DataService>.value(
            value: dataService,
            child: const MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Live Preview Ayah exists
      expect(find.text('معاينة حيّة مباشرة'), findsOneWidget);
      expect(find.text('﴿ إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ ﴾'), findsOneWidget);

      // 2. Font Size and Font Family options exist
      expect(find.text('حجم الخط العام'), findsOneWidget);
      expect(find.text('نوع وشكل الخط المعتمد'), findsOneWidget);
      expect(find.text('صغير (85%)'), findsOneWidget);
      expect(find.text('افتراضي (100%)'), findsOneWidget);
      expect(find.text('كبير (115%)'), findsOneWidget);

      // 3. Theme title exists, but palette names and subtitles are NOT rendered
      expect(find.text('ثيم التطبيق والألوان'), findsOneWidget);
      for (final pal in AppColors.palettes) {
        expect(find.text(pal.name), findsNothing);
        expect(find.text(pal.subtitle), findsNothing);
      }

      // 4. App Usage Mode options have been completely removed
      expect(find.text('نمط تشغيل واستخدام التطبيق'), findsNothing);
      expect(find.text('استخدام شخصي وعام'), findsNothing);
      expect(find.text('إدارة وكوادر المسجد'), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
