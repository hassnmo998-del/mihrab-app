// ignore_for_file: invalid_use_of_visible_for_testing_member
// يصوّر شاشات محراب الحقيقية لدليل الإدارة، رتبةً رتبة، بالتسلسل الذي يمرّ به المستخدم فعلاً. التشغيل:
//   flutter test tool/guide/capture_test.dart                (كل الرتب)
//   GUIDE_ONLY=portal,admin flutter test tool/guide/capture_test.dart
// الأجزاء: portal, superadmin, admin, women, sheikh, student, cashier
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/core/navigation/navigator_key.dart';
import 'package:flutter_app/main.dart' show MainShell;
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/discover/sheikh_live_lesson_screen.dart';
import 'package:flutter_app/screens/super_admin_screen.dart';
import 'package:flutter_app/services/data_service.dart';

import 'demo_story.dart';
import 'harness.dart';

final _only = (Platform.environment['GUIDE_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toSet();
bool _want(String part) => _only.isEmpty || _only.contains(part);

void main() {
  testWidgets('guide captures', (tester) async {
    GuideNetworkPolicy.install();
    // حواف الـ Row التي تفيض في شاشات حقيقية تُسجَّل ولا تُفشل التصوير
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString();
      if (msg.contains("deactivated widget's ancestor")) return;
      if (msg.contains('overflowed')) {
        stdout.writeln('! overflow: ${msg.split("\n").first}');
        return;
      }
      oldOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    await initInjection();
    final data = sl<DataService>();
    await data.completeOnboarding('personal');
    final story = seedDemoStory(data);

    final s = Shooter(tester, size: const Size(412, 892));
    await s.setUpView();
    addTearDown(tester.view.reset);
    await tester.pumpWidget(s.wrap(const GuideApp()));
    await s.settle(8);

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
        stdout.writeln('✓ $name');
      } catch (e, st) {
        stdout.writeln('✗ $name failed: $e\n${st.toString().split("\n").take(3).join("\n")}');
        await s.closeAll(); // نافذة عالقة لا تُفسد ما بعدها
      }
    }

    ActiveSession adminSession() => ActiveSession(
          role: 'mosque_admin', name: 'مدير جامع النور', code: story.mosque.accessCode,
          mosqueId: story.mosque.id, mosqueName: story.mosque.name,
        );
    ActiveSession sheikhSession() => ActiveSession(
          role: 'sheikh', name: story.ahmad.fullName, code: story.ahmad.code,
          mosqueId: story.mosque.id, mosqueName: story.mosque.name, sheikhId: story.ahmad.id,
        );
    ActiveSession studentSession(Student st, Mosque m) => ActiveSession(
          role: 'student', name: st.fullName, code: st.code, mosqueId: m.id, mosqueName: m.name,
          studentId: st.id, halaqaId: st.halaqaId,
        );
    ActiveSession cashierSession() => ActiveSession(
          role: 'cashier', name: 'أبو أحمد', code: story.mosque.effectiveCashierCode,
          mosqueId: story.mosque.id, mosqueName: story.mosque.name,
        );
    void lockAll() {
      for (final r in ['mosque_admin', 'sheikh', 'student', 'cashier']) {
        data.disconnectRole(r);
      }
    }

    Future<void> go(String tab) async {
      MainShell.targetTabNotifier.value = tab;
      await s.settle(8);
      await s.scrollToTop();
    }

    Future<void> closeAll() => s.closeAll();

    /// ينقر زراً نصه [button] أقرب ما يكون تحت العنوان [title].
    Future<void> tapBelow(String title, String button) async {
      final t = s.rectOf(s.textFinder(title))!;
      final all = s.textFinder(button).evaluate().toList();
      int? best;
      double bestDy = 1e9;
      for (var i = 0; i < all.length; i++) {
        final ro = all[i].renderObject as RenderBox;
        final dy = ro.localToGlobal(Offset.zero).dy - t.bottom;
        if (dy > -10 && dy < bestDy) {
          bestDy = dy;
          best = i;
        }
      }
      await s.tapFinder(s.textFinder(button), index: best ?? 0);
    }

    // ═════════ بوابة الإدارة والتفويض ═════════
    if (_want('portal')) {
      await step('home_01_public', () async {
        // الهاتف كما يصل إلى المستخدم العادي: خدمات عامة فقط، بلا أي لوحة إدارة
        await go('events');
        await s.snap('home_01_public');
      });
      await step('portal_01_one_role', () async {
        // طالب واحد مفتوح فقط: البوابة بحالتها المعتادة دون إعلان «قيد التفعيل»
        data.setRoleSession(studentSession(story.omar, story.mosque));
        await go('portal');
        await s.snap('portal_01_one_role');
        await s.scrollBy(-520);
        await s.snap('portal_01b_cards');
        await s.scrollToTop();
      });
      await step('portal scanner', () async {
        await s.scrollBy(-300);
        await tapBelow('إدارة المسجد ولجان الإشراف', 'مسح رمز QR أو إدخال الكود');
        await s.snap('portal_02_scanner');
        await s.typeInto('أدخل كود الاعتماد الممنوح لك', story.mosque.accessCode);
        await s.snap('portal_03_scanner_typed');
        await s.closeTop();
        await s.scrollToTop();
      });
      await step('portal many roles', () async {
        data.setRoleSession(adminSession());
        data.setRoleSession(sheikhSession());
        data.setRoleSession(cashierSession());
        await go('portal');
        await s.snap('portal_04_many_roles');
        await s.scrollBy(-420);
        await s.snap('portal_05_many_roles_cards');
        await s.scrollToTop();
        lockAll();
      });
    }

    // ═════════ المشرف العام وتأسيس المسجد ═════════
    if (_want('superadmin')) {
      await step('superadmin screen', () async {
        data.setRoleSession(studentSession(story.omar, story.mosque));
        await go('portal');
        appNavigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const SuperAdminScreen()));
        await s.settle(8);
        await s.snap('sa_01_panel');
        await s.tapText('توليد باركود جديد الآن');
        await s.snap('sa_02_generated');
        await s.scrollBy(-420);
        await s.snap('sa_03_tokens_and_mosques');
        await s.closeTop();
      });
      await step('registration flow', () async {
        await go('portal');
        await s.scrollBy(-300);
        await tapBelow('إدارة المسجد ولجان الإشراف', 'مسح رمز QR أو إدخال الكود');
        final token = data.getRegistrationTokens().last;
        await s.typeInto('أدخل كود الاعتماد الممنوح لك', token);
        await s.snap('sa_04_scan_reg_code');
        await s.tapText('تأكيد الدخول المعتمد');
        await s.settle(6);
        await s.snap('sa_05_registration_form');
        await s.typeInto('اسم المسجد *', 'جامع الرحمة');
        await s.typeInto('الحي / العنوان التفصيلي *', 'حي الشعلان، شارع بغداد');
        await s.typeInto('هاتف التواصل مع إدارة المسجد', '0933456789');
        await s.snap('sa_06_registration_form_filled');
        await s.closeTop();
      });
      await closeAll();
      lockAll();
    }

    // ═════════ مدير المسجد ═════════
    if (_want('admin')) {
      data.setRoleSession(adminSession());
      await go('mosque_admin');
      await step('admin_00_header', () => s.snap('admin_00_header'));
      for (final (tip, name) in [
        ('تعديل معلومات المسجد', 'admin_01a_edit_mosque'),
        ('بطاقة مدير المسجد والباركود', 'admin_01b_manager_card'),
        ('رمز اعتماد الصراف ', 'admin_01d_cashier_qr'),
      ]) {
        await step(name, () async {
          await s.tapTooltip(tip);
          await s.snap(name);
          await s.closeTop();
        });
      }
      // ── المشايخ ──
      await step('admin sheikhs', () async {
        await s.tapTab('المشايخ والمعلمات');
        await s.snap('admin_02_sheikhs');
        // بطاقة الاعتماد أولاً: بعد إغلاق نافذة الإضافة تُعاد بناء القائمة بسياق منتهٍ في وضع الـ debug
        await s.tapIcon(Icons.qr_code);
        await s.snap('admin_02c_sheikh_card');
        await s.closeAll();
        await s.tapText('إضافة شيخ جديد');
        await s.snap('admin_02a_add_sheikh');
        await s.typeInto('الاسم الكامل *', 'الشيخ إبراهيم الدمشقي');
        await s.typeInto('رقم الهاتف *', '0933777888');
        await s.snap('admin_02b_add_sheikh_filled');
        await s.closeAll();
      });
      // ── الحلقات ──
      await step('admin halaqat', () async {
        await s.tapTab('الحلقات القرآنية');
        await s.snap('admin_03_halaqat');
        await s.tapText('إضافة حلقة جديدة');
        await s.typeInto('اسم الحلقة *', 'حلقة التبيان');
        await s.snap('admin_03a_add_halaqa');
        await s.scrollBy(-300, at: const Offset(206, 600));
        await s.snap('admin_03b_add_halaqa_schedule');
        await closeAll();
      });
      // ── الطلاب ──
      await step('admin students', () async {
        await s.tapTab('إدارة الطلاب');
        await s.snap('admin_04_students');
        await s.tapText('تسجيل طالب جديد');
        await s.typeInto('الاسم الثلاثي للطالب *', 'أحمد سامر الخطيب');
        await s.typeInto('رقم هاتف التواصل (ولي الأمر) *', '0944321654');
        await s.typeInto('عمر الطالب (بالسنوات)', '9');
        await s.snap('admin_04a_add_student');
        await closeAll();
        await s.tapTooltip('بطاقة الطالب الرقمية QR');
        await s.snap('admin_04b_student_card');
        await closeAll();
        await s.tapTooltip('وضع نقاط يدوي (إضافة / خصم)');
        await s.snap('admin_04c_manual_points');
        await closeAll();
      });
      await step('admin messages', () async {
        await s.tapTab('رسائل وتواصل الطلاب');
        await s.snap('admin_05_messages');
      });
      await step('admin courses', () async {
        await s.tapTab('الدورات الاستثنائية');
        await s.snap('admin_06_courses');
        await s.tapText('إضافة دورة استثنائية');
        await s.snap('admin_06a_add_course');
        await closeAll();
      });
      await step('admin trips', () async {
        await s.tapTab('رحلات وأنشطة المسجد');
        await s.snap('admin_07_trips');
        await s.tapText('إضافة رحلة جديدة');
        await s.snap('admin_07a_add_trip');
        await closeAll();
      });
      await step('admin tracks', () async {
        await s.tapTab('المناهج والمتون');
        await s.snap('admin_08_tracks');
        await s.tapText('إضافة منهج / متن جديد');
        await s.typeInto('اسم المنهج أو المتن *', 'متن تحفة الأطفال');
        await s.snap('admin_08a_add_track');
        await closeAll();
      });
      await step('admin rewards', () async {
        await s.tapTab('بنك الجوائز');
        await s.snap('admin_09_rewards');
        await s.tapText('إضافة جائزة جديدة');
        await s.typeInto('اسم الجائزة أو المكافأة *', 'مصحف مفسَّر');
        await s.typeInto('سعر الجائزة بالنقاط *', '200');
        await s.snap('admin_09a_add_reward');
        await closeAll();
      });
      await step('admin overview', () async {
        await s.tapTab('لوحة المتابعة الشاملة');
        await s.snap('admin_10_overview');
        await s.scrollBy(-300);
        await s.snap('admin_10b_overview_scrolled');
        await s.scrollToTop();
        await s.tapText('إعدادات');
        await s.snap('admin_10a_shamcash');
        await closeAll();
      });
      await step('admin events', () async {
        await s.tapTab('الفعاليات ومجالس العلم');
        await s.snap('admin_11_events');
        await s.tapText('إعلان عن درس / مجلس');
        await s.snap('admin_11a_add_event');
        await closeAll();
      });
      await step('admin studio', () async {
        await s.tapTab('مركز التصاميم والطباعة');
        await s.snap('admin_12_studio_cards');
        await s.scrollBy(-420);
        await s.snap('admin_12b_studio_cards_scrolled');
        await s.scrollToTop();
        await s.tapText('استوديو لوحات الشرف وبوسترات التكريم');
        await s.snap('admin_12c_studio_honor');
        await s.scrollBy(-420);
        await s.snap('admin_12d_studio_honor_scrolled');
      });
      lockAll();
    }

    // ═════════ القسم النسائي ═════════
    if (_want('women')) {
      await step('women provision', () async {
        data.setRoleSession(adminSession());
        await go('mosque_admin');
        await s.tapTooltip('إنشاء إدارة القسم النسائي');
        await s.snap('women_01_provision_dialog');
        await s.tapText('إصدار رمز إنشاء القسم النسائي');
        await s.snap('women_02_provision_qr');
        await closeAll();
        lockAll();
      });
      await step('women scan', () async {
        data.setRoleSession(studentSession(story.omar, story.mosque));
        await go('portal');
        await s.scrollBy(-700);
        await s.snap('women_03_portal_card');
        await tapBelow('القسم النسائي (إدارة النساء)', 'مسح رمز QR أو إدخال الكود');
        final token = data.issueWomenProvisionToken(story.mosque.id) ?? '';
        await s.typeInto('أدخلي رمز القسم النسائي', token);
        await s.snap('women_04_scan_wmv');
        await s.tapText('تأكيد الدخول المعتمد');
        await s.settle(6);
        await s.snap('women_05_setup_dialog');
        await s.typeInto('الحي / العنوان', 'حي الميدان، دمشق');
        await s.typeInto('هاتف التواصل (اختياري)', '0933555777');
        await s.snap('women_05b_setup_filled');
        await s.tapText('إنشاء الإدارة النسائية');
        await s.settle(10);
      });
      await step('women dashboard', () async {
        await closeAll();
        await go('mosque_admin');
        await s.snap('women_06_dashboard');
        await s.tapText('إضافة معلمة حلقة');
        await s.snap('women_07_add_teacher');
        await closeAll();
      });
      await closeAll();
      lockAll();
    }

    // ═════════ الشيخ ═════════
    if (_want('sheikh')) {
      data.setRoleSession(sheikhSession());
      await go('sheikh');
      await step('sheikh_00_header', () => s.snap('sheikh_00_header'));
      await step('sheikh attendance', () async {
        await s.tapTab('رصد الحضور اليومي');
        await s.snap('sheikh_01_attendance');
        await s.tapText('نقاط الحضور');
        await s.snap('sheikh_01a_attendance_points');
        await closeAll();
        await s.tapText('حاضر', index: 0);
        await s.snap('sheikh_01b_attendance_marked');
        await s.scrollBy(-300);
        await s.snap('sheikh_01c_attendance_list');
      });
      await step('sheikh recitation', () async {
        await s.tapTab('رصد التسميع والقرآن');
        await s.snap('sheikh_02_recitation');
        await s.scrollBy(-420);
        await s.snap('sheikh_02b_recitation_form');
        await s.scrollBy(-420);
        await s.snap('sheikh_02c_recitation_points');
        await s.scrollToTop();
        await s.tapText('سور كاملة');
        await s.snap('sheikh_02d_recitation_surahs');
        await s.tapText('أجزاء كاملة');
        await s.snap('sheikh_02e_recitation_juz');
      });
      await step('sheikh tracks', () async {
        await s.tapTab('المناهج والمتون');
        await s.snap('sheikh_03_tracks');
      });
      await step('sheikh trips', () async {
        await s.tapTab('رحلات وأنشطة الحلقة');
        await s.snap('sheikh_04_trips');
      });
      await step('sheikh overview', () async {
        await s.tapTab('لوحة المتابعة الشاملة');
        await s.snap('sheikh_05_overview');
      });
      await step('sheikh events', () async {
        await s.tapTab('إدارة دروسي العامة');
        await s.snap('sheikh_06_events');
        await s.tapText('إعلان درس جديد');
        await s.snap('sheikh_06a_announce');
        await closeAll();
      });
      await step('sheikh live studio', () async {
        final lesson = data.getCommunityEvents(mosqueId: story.mosque.id).first;
        appNavigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => SheikhLiveLessonScreen(event: lesson)));
        await s.settle(10);
        await s.snap('sheikh_06b_live_studio');
        await s.scrollBy(-300);
        await s.snap('sheikh_06c_live_studio_2');
        await closeAll();
      });
      await step('sheikh students', () async {
        await s.tapTab('طلاب الحلقة والـ QR');
        await s.snap('sheikh_07_students');
        await s.tapText('تسجيل طالب جديد');
        await s.snap('sheikh_07a_add_student');
        await closeAll();
        await s.tapTooltip('بطاقة الطالب الرقمية / QR');
        await s.snap('sheikh_07b_student_card');
        await closeAll();
      });
      await step('sheikh messages', () async {
        await s.tapTab('رسائل وتواصل الأهل');
        await s.snap('sheikh_08_messages');
        await s.tapText('عمر خالد');
        await s.snap('sheikh_08a_thread');
      });
      lockAll();
    }

    // ═════════ الطالب وولي الأمر ═════════
    if (_want('student')) {
      data.setRoleSession(studentSession(story.omar, story.mosque));
      await go('student');
      await step('student_00_header', () => s.snap('student_00_header'));
      await step('student add child flow', () async {
        final row = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal).first;
        await s.revealInRow(s.textFinder('إضافة ابن'), row);
        await s.snap('student_00a_add_child_button');
        await s.tapText('إضافة ابن');
        await s.typeInto('أدخل كود الاعتماد الممنوح لك', story.saeed.code);
        await s.snap('student_00b_add_child_scan');
        await s.tapText('تأكيد الدخول المعتمد');
        await s.settle(6);
        data.addStudentSession(studentSession(story.abdullah, story.otherMosque));
        await s.settle(6);
        await s.scrollToTop();
        await s.snap('student_00c_three_children');
        data.setActiveStudent(story.omar.id);
        await s.settle(6);
      });
      await step('student progress', () async {
        await s.tapTab('تقدم حفظ القرآن والمناهج');
        await s.snap('student_01_progress');
        await s.scrollBy(-380);
        await s.snap('student_01b_juz_map');
        await s.scrollBy(-1700);
        await s.snap('student_01c_juz_map_end');
        await s.scrollBy(-1500);
        await s.snap('student_01d_tracks_and_log');
        await s.scrollToTop();
        await s.tapText('الجزء الأول');
        await s.snap('student_01e_juz_modal');
        await closeAll();
      });
      const tabs = [
        ('سجل الحضور والالتزام', 'student_02_attendance'),
        ('رحلاتي وأنشطتي', 'student_03_trips'),
        ('متجر الجوائز', 'student_04_rewards'),
        ('سجل النقاط', 'student_05_points'),
        ('تواصل مع الشيخ', 'student_06_contact'),
        ('ترتيب الطالب', 'student_07_rank'),
      ];
      for (final (label, name) in tabs) {
        await step(name, () async {
          await s.tapTab(label);
          await s.snap(name);
        });
      }
      await step('rankings tab', () async {
        await go('rankings');
        await s.snap('rank_01_board');
      });
      lockAll();
    }

    // ═════════ أمين الصندوق ═════════
    if (_want('cashier')) {
      data.setRoleSession(cashierSession());
      await go('cashier');
      await step('cashier_00_home', () => s.snap('cashier_00_home'));
      await step('cashier add mosque', () async {
        await s.tapText('إضافة جامع');
        await s.snap('cashier_01_add_mosque');
        await closeAll();
      });
      await step('cashier second mosque', () async {
        data.setRoleSession(ActiveSession(
          role: 'cashier', name: 'أبو أحمد', code: story.otherMosque.effectiveCashierCode,
          mosqueId: story.otherMosque.id, mosqueName: story.otherMosque.name,
        ));
        await go('cashier');
        await s.snap('cashier_02_two_mosques');
      });
      await step('cashier scan student', () async {
        await s.tapText('مسح باركود الطالب');
        await s.snap('cashier_03_scan_student');
        await closeAll();
      });
      await step('cashier dispense', () async {
        await s.typeInto('كود الطالب أو القسيمة', story.omar.code);
        await s.snap('cashier_04_code_typed');
        await s.tapText('صرف');
        await s.snap('cashier_05_dispense_dialog');
        await s.tapText('صرف وتسليم', index: 0);
        await s.snap('cashier_06_dispensed');
        await closeAll();
      });
      await step('cashier records', () async {
        await go('cashier');
        await s.tapText('السجلات والكشوف');
        await s.snap('cashier_07_records');
        await s.scrollBy(-400);
        await s.snap('cashier_07b_records_scrolled');
      });
      lockAll();
    }
  });
}
