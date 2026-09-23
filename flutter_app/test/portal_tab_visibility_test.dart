import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/presentation/blocs/blocs.dart';
import 'package:flutter_app/screens/management_portal/management_portal_screen.dart';
import 'package:flutter_app/services/data_service.dart';

/// Tabs unlocked from the authorization portal: the student tab appears only after a
/// student code is scanned, and rankings open with any unlocked tab except cashier-only.
void main() {
  late DataService data;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initInjection();
    data = sl<DataService>();
  });

  setUp(() {
    for (final role in ['mosque_admin', 'sheikh', 'cashier', 'student']) {
      data.disconnectRole(role);
    }
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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
          value: data,
          child: const MaterialApp(home: MainShell()),
        ),
      ),
    );
    await tester.pump();
  }

  ActiveSession session(String role, String code) =>
      ActiveSession(role: role, code: code, name: 'اختبار $role');

  testWidgets('Visitor: no student tab and no rankings', (tester) async {
    await pumpShell(tester);
    expect(find.text('تفاصيل الطالب'), findsNothing);
    expect(find.text('لوحة الترتيب'), findsNothing);
    expect(find.text('القرآن الكريم'), findsOneWidget);
  });

  testWidgets('Scanned student: student tab and rankings appear', (tester) async {
    data.setRoleSession(session('student', 'STD-TEST-1'));
    await pumpShell(tester);
    expect(find.text('تفاصيل الطالب'), findsOneWidget);
    expect(find.text('لوحة الترتيب'), findsOneWidget);
  });

  testWidgets('Scanned sheikh: rankings appear, student tab stays hidden', (tester) async {
    data.setRoleSession(session('sheikh', 'SHK-TEST-1'));
    await pumpShell(tester);
    expect(find.text('إدارة الحلقة'), findsOneWidget);
    expect(find.text('لوحة الترتيب'), findsOneWidget);
    expect(find.text('تفاصيل الطالب'), findsNothing);
  });

  testWidgets('Cashier only: no rankings', (tester) async {
    data.setRoleSession(session('cashier', 'CSH-TEST-1'));
    await pumpShell(tester);
    expect(find.text('صراف الجوائز'), findsOneWidget);
    expect(find.text('لوحة الترتيب'), findsNothing);
  });

  testWidgets('Portal lists a locked student card', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DataService>.value(
        value: data,
        child: const MaterialApp(home: ManagementPortalScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('الطالب وولي الأمر'), findsOneWidget);
  });
}
