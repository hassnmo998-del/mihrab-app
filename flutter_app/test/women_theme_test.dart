import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/presentation/blocs/theme/theme_cubit.dart';
import 'package:flutter_app/services/data_service.dart';

/// أي كود لقسم نسائي يحوّل التطبيق إلى الباقة الزهرية الموجودة، مرة واحدة،
/// ويعود الثيم السابق حين تخرج المستخدمة من كل الأقسام النسائية.
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

  Mosque mosque(String gender) =>
      data.addMosque(name: 'جامع $gender', address: '', city: 'دمشق', gender: gender, phone: '');

  Future<ThemeCubit> openCubit(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final cubit = ThemeCubit(dataService: data);
    await settle(cubit);
    return cubit;
  }

  test('الزهري باقة موجودة بين باقات التطبيق لا باقة جديدة', () {
    expect(AppColors.palettes.map((p) => p.id), contains(AppColors.womenPaletteId));
  });

  for (final role in ['mosque_admin', 'sheikh', 'student', 'cashier']) {
    test('كود قسم نسائي بصفة $role يحوّل الثيم إلى الزهري فوراً', () async {
      final cubit = await openCubit({'palette_id': 'emerald'});
      expect(cubit.state.paletteId, 'emerald');

      final women = mosque('female');
      data.setRoleSession(ActiveSession(role: role, code: 'W-$role', mosqueId: women.id, gender: 'female'));
      await settle(cubit);

      expect(cubit.state.paletteId, AppColors.womenPaletteId);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('palette_id'), AppColors.womenPaletteId);
      expect(prefs.getString(ThemeCubit.paletteBeforeWomenKey), 'emerald');
      await cubit.close();
    });
  }

  test('كود لقسم الرجال لا يغيّر الثيم', () async {
    final cubit = await openCubit({'palette_id': 'kaaba'});
    final men = mosque('male');
    data.setRoleSession(ActiveSession(role: 'sheikh', code: 'M-1', mosqueId: men.id, gender: 'male'));
    await settle(cubit);

    expect(cubit.state.paletteId, 'kaaba');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeCubit.paletteBeforeWomenKey), isNull);
    await cubit.close();
  });

  test('الخروج من كل الأقسام النسائية يعيد الثيم السابق', () async {
    final cubit = await openCubit({'palette_id': 'sapphire'});
    final women = mosque('female');
    data.setRoleSession(ActiveSession(role: 'student', code: 'W-S', mosqueId: women.id, gender: 'female'));
    await settle(cubit);
    expect(cubit.state.paletteId, AppColors.womenPaletteId);

    data.disconnectRole('student');
    await settle(cubit);

    expect(cubit.state.paletteId, 'sapphire');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeCubit.paletteBeforeWomenKey), isNull);
    await cubit.close();
  });

  test('من غيّرت الثيم بيدها يبقى اختيارها: لا يُعاد الزهري ولا يُمسح عند الخروج', () async {
    final cubit = await openCubit({'palette_id': 'emerald'});
    final women = mosque('female');
    data.setRoleSession(ActiveSession(role: 'sheikh', code: 'W-T', mosqueId: women.id, gender: 'female'));
    await settle(cubit);

    await cubit.setPalette('teal');
    // أي تحديث للبيانات (مزامنة، درس جديد...) لا يعيد الزهري
    data.setRoleSession(ActiveSession(role: 'cashier', code: 'W-C', mosqueId: women.id, gender: 'female'));
    await settle(cubit);
    expect(cubit.state.paletteId, 'teal');

    data.disconnectRole('sheikh');
    data.disconnectRole('cashier');
    await settle(cubit);
    expect(cubit.state.paletteId, 'teal');
    await cubit.close();
  });

  test('فتح التطبيق وهو في الحالة النسائية من قبل لا يفرض الزهري من جديد', () async {
    final women = mosque('female');
    data.setRoleSession(ActiveSession(role: 'student', code: 'W-OLD', mosqueId: women.id, gender: 'female'));

    final cubit = await openCubit({
      'palette_id': 'amber',
      ThemeCubit.paletteBeforeWomenKey: 'terracotta',
    });

    expect(cubit.state.paletteId, 'amber');
    await cubit.close();
  });
}

/// ينتظر قراءة الإعدادات ثم اكتمال آخر تغيير في ثيم القسم النسائي.
Future<void> settle(ThemeCubit cubit) async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cubit.womenPaletteSettled;
  }
}
