import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/presentation/blocs/blocs.dart';
import 'package:flutter_app/screens/settings_screen.dart';
import 'package:flutter_app/screens/management_portal/management_portal_screen.dart';
import 'package:flutter_app/screens/competition/tabs/competition_courses_tab.dart';
import 'package:flutter_app/screens/student/tabs/student_rankings_tab.dart';
import 'package:flutter_app/screens/discover/widgets/hadith_card.dart';
import 'package:flutter_app/screens/discover/widgets/athkar_and_hadith_view.dart';
import 'package:flutter_app/screens/discover/widgets/prayer_times_qibla_view.dart';
import 'package:flutter_app/screens/discover/widgets/quran_reader_view.dart';
import 'package:flutter_app/services/hadith_service.dart';
import 'package:flutter_app/services/quran_service.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initInjection();
  });

  group('Mobile Navigation & Settings Tests', () {
    testWidgets('MainShell does NOT render any NavigationBar at bottom', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataService = sl<DataService>();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SessionBloc>(create: (_) => sl<SessionBloc>()),
            BlocProvider<ThemeCubit>(create: (_) => sl<ThemeCubit>()),
            BlocProvider<TripsBloc>(create: (_) => sl<TripsBloc>()),
            BlocProvider<CoursesBloc>(create: (_) => sl<CoursesBloc>()),
            BlocProvider<AttendanceBloc>(create: (_) => sl<AttendanceBloc>()),
            BlocProvider<RewardsBloc>(create: (_) => sl<RewardsBloc>()),
            BlocProvider<CompetitionsBloc>(create: (_) => sl<CompetitionsBloc>()),
            BlocProvider<RecitationBloc>(create: (_) => sl<RecitationBloc>()),
          ],
          child: ChangeNotifierProvider<DataService>.value(
            value: dataService,
            child: const MaterialApp(
              home: MainShell(),
            ),
          ),
        ),
      );

      await tester.pump();

      // NavigationBar & BottomNavigationBar must NOT be present
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('SettingsScreen does NOT contain 130% font option', (tester) async {
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

      // 130% option must NOT exist
      expect(find.text('كبير جداً (130%)'), findsNothing);

      // Remaining options must exist
      expect(find.text('صغير (85%)'), findsOneWidget);
      expect(find.text('افتراضي (100%)'), findsOneWidget);
      expect(find.text('كبير (115%)'), findsOneWidget);
    });

    test('ThemeCubit clamps fontScale to 1.15 max', () {
      final cubit = sl<ThemeCubit>();
      cubit.setFontScale(1.30);
      expect(cubit.state.fontScale, lessThanOrEqualTo(1.15));
      expect(cubit.state.fontScale, equals(1.15));

      cubit.setFontScale(1.0);
      expect(cubit.state.fontScale, equals(1.0));
    });

    testWidgets('ManagementPortalScreen renders on narrow phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataService = sl<DataService>();

      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: dataService,
          child: const MaterialApp(
            home: Scaffold(
              body: ManagementPortalScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('بوابة الإدارة والتفويض'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CompetitionCoursesTab renders on narrow phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataService = sl<DataService>();

      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: dataService,
          child: const MaterialApp(
            home: Scaffold(
              body: CompetitionCoursesTab(gender: 'male'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.textContaining('الدورات القرآنية الاستثنائية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StudentRankingsTab renders on narrow phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dataService = sl<DataService>();
      final dummyStudent = Student(
        id: 'std_test',
        mosqueId: 'm1',
        halaqaId: 'h1',
        fullName: 'فوزي الطالب المتفوق ذو الاسم الطويل جداً',
        code: 'STD-1234',
        gender: 'male',
        phone: '0999123456',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<DataService>.value(
          value: dataService,
          child: MaterialApp(
            home: Scaffold(
              body: StudentRankingsTab(student: dummyStudent),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('HadithCard renders long narrator and riyad badge without overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hadith = NawawiHadith(
        number: 1,
        title: 'الأعمال بالنيات',
        narrator: 'عن أمير المؤمنين أبي حفص عمر بن الخطاب رضي الله عنه',
        matn: 'إنما الأعمال بالنيات وإنما لكل امرئ ما نوى',
        source: 'رواه البخاري ومسلم',
        fawaid: 'إخلاص النية لله تعالى',
        book: 'riyad',
        chapter: 'رياض الصالحين (التربية والأخلاق)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HadithCard(
                hadith: hadith,
                isDark: false,
                fontSize: 18.0,
                onCopy: () {},
                onShare: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('الأعمال بالنيات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AthkarAndHadithView reset counters bar renders without overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AthkarAndHadithView(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('اضغط على بطاقة الذكر للعد التنازلي التفاعلي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrayerTimesQiblaView renders without overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrayerTimesQiblaView(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('بوصلة القبلة التفاعلية الحية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QuranReaderView renders long surahs like سورة الذاريات without overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      QuranService.setMockLoadedForTesting();

      // The Quran section is a full-screen tab, so the reader gets bounded height.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuranReaderView(onExit: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.enterText(find.byType(TextField), 'الذاريات');
      await tester.pump();

      expect(find.text('سورة الذاريات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
