// أدوات تصوير الدليل: تشغّل شاشات محراب الحقيقية داخل اختبار Flutter، بخطوطها وبياناتها التجريبية،
// وتحفظ كل لقطة PNG مع مستطيلات العناصر التي سيشير إليها الفيديو (من شجرة الواجهة نفسها لا بالتقدير).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/core/navigation/navigator_key.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/main.dart' show MainShell;
import 'package:flutter_app/presentation/blocs/blocs.dart';
import 'package:flutter_app/screens/onboarding/app_onboarding_screen.dart';
import 'package:flutter_app/services/data_service.dart';

/// مجلد الإخراج: GUIDE_OUT أو المجلد الافتراضي بجوار الصوت.
String get guideOut => Platform.environment['GUIDE_OUT'] ?? r'C:\clurlelo\output\mihrab_guide\shots';

String get guideCache => Platform.environment['GUIDE_CACHE'] ?? r'C:\clurlelo\output\mihrab_guide\cache';

Set<int> _emojiCps = {};
Set<int> _emojiMods = {};

/// لا بيانات تخرج من الجهاز: الاتصال مسموح بخوادم خطوط Google وحدها (كما يجلبها التطبيق الحقيقي
/// للخطوط الثقيلة)، وكل ما عداها، ومنه Supabase، يُرفض قبل أن يبدأ.
class GuideNetworkPolicy extends HttpOverrides {
  static bool allowed(Uri u) => u.host.endsWith('gstatic.com') || u.host.endsWith('googleapis.com');

  static void install() => HttpOverrides.global = GuideNetworkPolicy();

  @override
  HttpClient createHttpClient(SecurityContext? context) => _GuardedClient(super.createHttpClient(context));
}

/// عميل HTTP يرفض أي مضيف غير مسموح قبل فتح الاتصال.
class _GuardedClient implements HttpClient {
  _GuardedClient(this._inner);
  final HttpClient _inner;

  void _check(Uri u) {
    if (!GuideNetworkPolicy.allowed(u)) throw SocketException('guide capture: ${u.host} is blocked');
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    _check(url);
    return _inner.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: port == 443 ? 'https' : 'http', host: host, port: port, path: path));

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? v) => _inner.userAgent = v;
  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool v) => _inner.autoUncompress = v;
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? v) => _inner.connectionTimeout = v;
  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration v) => _inner.idleTimeout = v;
  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? v) => _inner.maxConnectionsPerHost = v;
  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> loadFontFile(WidgetTester t, String family, List<String> paths) async {
  await t.runAsync(() async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = await File(p).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });
}

/// خطوط التطبيق الحقيقية + أيقونات Material من الـ SDK، وإلا ظهرت المربعات.
Future<void> loadAppFonts(WidgetTester t) async {
  await loadFontFile(t, 'Amiri', ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf']);
  await loadFontFile(t, 'Cairo', ['assets/fonts/Cairo-Regular.ttf']);
  await loadFontFile(t, 'Tajawal', ['assets/fonts/Tajawal-Regular.ttf', 'assets/fonts/Tajawal-Bold.ttf']);
  await loadFontFile(t, 'NotoNaskhArabic', [
    'assets/fonts/NotoNaskhArabic-SemiBold.ttf',
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  ]);
  await loadFontFile(t, 'BlankEmoji', ['$guideCache/blank_emoji.ttf']);
  final cps = jsonDecode(File('$guideCache/emoji_cps.json').readAsStringSync()) as Map<String, dynamic>;
  _emojiCps = (cps['emoji'] as List).cast<int>().toSet();
  _emojiMods = (cps['modifiers'] as List).cast<int>().toSet();
  // path_provider في الاختبار بلا منصّة: مجلد مؤقت يكفي لتخزين الخطوط المجلوبة
  final scratch = Directory.systemTemp.createTempSync('guide_fonts_').path;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => scratch,
  );
  // خطوط Google التي يجلبها التطبيق وقت التشغيل (الثقيلة): تُجلب هنا بالزمن الحقيقي،
  // لأن مؤقّتات الاختبار المزيّفة تقطع مصافحة TLS إن جرى الجلب أثناء pump.
  await t.runAsync(() async {
    for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
      GoogleFonts.cairo(fontWeight: w);
      GoogleFonts.amiri(fontWeight: w);
    }
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 40), onTimeout: () => const []);
  });
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  await loadFontFile(t, 'MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  final cupertino = File('.dart_tool/package_config.json');
  if (cupertino.existsSync()) {
    final cfg = jsonDecode(cupertino.readAsStringSync()) as Map<String, dynamic>;
    final pkg = (cfg['packages'] as List).cast<Map<String, dynamic>>().firstWhere(
          (p) => p['name'] == 'cupertino_icons',
          orElse: () => const {},
        );
    if (pkg.isNotEmpty) {
      final dir = Uri.parse(pkg['rootUri'] as String);
      final base = dir.isAbsolute ? dir.toFilePath() : File('.dart_tool/${pkg['rootUri']}').absolute.parent.path;
      final ttf = File('$base/assets/CupertinoIcons.ttf');
      if (ttf.existsSync()) {
        await loadFontFile(t, 'packages/cupertino_icons/CupertinoIcons', [ttf.path]);
      }
    }
  }
}

/// مستطيل عنصر على اللقطة (بكسلات منطقية، نقطة الأصل أعلى اليسار).
class Hot {
  Hot(this.id, this.rect);
  final String id;
  final Rect rect;
  Map<String, dynamic> toJson() => {
        'id': id,
        'x': rect.left,
        'y': rect.top,
        'w': rect.width,
        'h': rect.height,
      };
}

/// كل إيموجي ظاهر الآن على الشاشة: نصه ومستطيله (من شجرة الرسم نفسها) وحجم خطه.
/// يرسمه الفيديو ملوّناً فوق الفراغ الذي يتركه خط BlankEmoji.
List<Map<String, dynamic>> scanEmoji(RenderObject root, Size view, int viewId) {
  final out = <Map<String, dynamic>>[];
  void walk(RenderObject r) {
    if (r is RenderOffstage && r.offstage) return;
    if (r is RenderParagraph) {
      final text = r.text.toPlainText();
      var i = 0;
      while (i < text.length) {
        final rune = text.runes.isEmpty ? 0 : _runeAt(text, i);
        final width = rune > 0xFFFF ? 2 : 1;
        if (_emojiCps.contains(rune)) {
          var end = i + width;
          while (end < text.length) {
            final n = _runeAt(text, end);
            final nw = n > 0xFFFF ? 2 : 1;
            if (_emojiMods.contains(n)) {
              end += nw;
              if (n == 0x200D && end < text.length) {
                final n2 = _runeAt(text, end);
                if (_emojiCps.contains(n2)) end += n2 > 0xFFFF ? 2 : 1;
              }
            } else {
              break;
            }
          }
          final boxes = r.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: end));
          if (boxes.isNotEmpty) {
            var rect = boxes.first.toRect();
            for (final b in boxes.skip(1)) {
              rect = rect.expandToInclude(b.toRect());
            }
            final origin = r.localToGlobal(rect.topLeft);
            final global = origin & rect.size;
            // إيموجي تحت نافذة أو حاجز معتم لا يُرسم: نسأل الواجهة هل تصله اللمسة فعلاً
            final hit = HitTestResult();
            RendererBinding.instance.hitTestInView(hit, global.center, viewId);
            final visible = hit.path.any((e) => identical(e.target, r));
            if (visible && global.overlaps(Offset.zero & view)) {
              final span = r.text.getSpanForPosition(TextPosition(offset: i));
              final size = (span?.style?.fontSize ?? r.text.style?.fontSize ?? 14).toDouble();
              out.add({
                't': text.substring(i, end),
                'x': global.left,
                'y': global.top,
                'w': global.width,
                'h': global.height,
                'size': size,
              });
            }
          }
          i = end;
        } else {
          i += width;
        }
      }
    }
    r.visitChildren(walk);
  }

  walk(root);
  return out;
}

/// أهداف الإشارة على اللقطة: الأزرار (بنصها)، الأدوات ذات التلميح، الحقول، وكل نص ظاهر.
/// تُقرأ من شجرة الواجهة نفسها، فيشير الفيديو إلى مكان العنصر الحقيقي لا إلى تقدير.
Map<String, List<Map<String, dynamic>>> scanTargets(Element root, Size view) {
  final screen = Offset.zero & view;
  final buttons = <Map<String, dynamic>>[];
  final tips = <Map<String, dynamic>>[];
  final fields = <Map<String, dynamic>>[];
  final texts = <Map<String, dynamic>>[];

  Rect? rectOfElement(Element e) {
    final ro = e.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final r = ro.localToGlobal(Offset.zero) & ro.size;
    return r.overlaps(screen) ? r : null;
  }

  String textsUnder(Element e) {
    final out = <String>[];
    void v(Element x) {
      final w = x.widget;
      if (w is Text) {
        final d = w.data ?? w.textSpan?.toPlainText();
        if (d != null && d.trim().isNotEmpty) out.add(d.trim());
      }
      x.visitChildren(v);
    }

    v(e);
    return out.join(' ');
  }

  Map<String, dynamic> pack(Rect r, Map<String, dynamic> extra) =>
      {'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height, ...extra};

  void walk(Element e) {
    final w = e.widget;
    if (w is Offstage && w.offstage) return;
    if (w is Tooltip && w.message != null) {
      final r = rectOfElement(e);
      if (r != null) tips.add(pack(r, {'t': w.message}));
    } else if (w is ButtonStyleButton) {
      final r = rectOfElement(e);
      if (r != null) buttons.add(pack(r, {'t': textsUnder(e)}));
    } else if (w is TextField) {
      final r = rectOfElement(e);
      final label = w.decoration?.labelText ?? w.decoration?.hintText;
      if (r != null && label != null) fields.add(pack(r, {'t': label}));
    }
    e.visitChildren(walk);
  }

  root.visitChildren(walk);

  void walkRender(RenderObject r) {
    if (r is RenderOffstage && r.offstage) return;
    if (r is RenderParagraph) {
      final t = r.text.toPlainText().trim();
      if (t.isNotEmpty && r.hasSize && r.attached) {
        final rect = r.localToGlobal(Offset.zero) & r.size;
        if (rect.overlaps(screen)) texts.add(pack(rect, {'t': t}));
      }
    }
    r.visitChildren(walkRender);
  }

  final ro = root.findRenderObject();
  if (ro != null) walkRender(ro);
  return {'buttons': buttons, 'tips': tips, 'fields': fields, 'texts': texts};
}

int _runeAt(String s, int i) {
  final c = s.codeUnitAt(i);
  if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
    final d = s.codeUnitAt(i + 1);
    if (d >= 0xDC00 && d <= 0xDFFF) return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00);
  }
  return c;
}

class Shooter {
  Shooter(this.t, {required this.size, this.pixelRatio = 3});

  final WidgetTester t;
  final Size size;
  final double pixelRatio;
  final GlobalKey boundary = GlobalKey();
  final Map<String, dynamic> manifest = _loadManifest();

  static Map<String, dynamic> _loadManifest() {
    final f = File('$guideOut/manifest.json');
    return f.existsSync() ? Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map) : {};
  }

  Future<void> setUpView() async {
    t.view.physicalSize = size * 1.0;
    t.view.devicePixelRatio = 1.0;
  }

  Widget wrap(Widget app) => RepaintBoundary(key: boundary, child: app);

  /// يترك الرسوم والصور والانتقالات تهدأ دون انتظار رسوم لا تنتهي.
  Future<void> settle([int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await t.pump(const Duration(milliseconds: 120));
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 8), onTimeout: () => const []);
      });
    }
    await t.pump(const Duration(milliseconds: 400));
  }

  Rect? rectOf(Finder f, {int index = 0}) {
    final found = f.evaluate();
    if (found.length <= index) return null;
    final box = found.elementAt(index).renderObject;
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// مستطيل أول نص بهذه الصياغة على الشاشة الآن (أو `null` إن لم يظهر).
  Hot? hotText(String text, {String? id, int index = 0, bool skipOffstage = true}) {
    final r = rectOf(find.text(text, skipOffstage: skipOffstage), index: index);
    return r == null ? null : Hot(id ?? text, r);
  }

  List<Hot> hots(Iterable<String> texts) => [for (final x in texts) ?hotText(x)];

  /// يعيد كل قائمة عمودية إلى أولها (ترويسة الإدارة وشريط التبويبات تنطوي عند التمرير).
  Future<void> scrollToTop() async {
    for (final e in find.byType(Scrollable).evaluate()) {
      final st = (e as StatefulElement).state as ScrollableState;
      if (st.axisDirection == AxisDirection.down || st.axisDirection == AxisDirection.up) {
        if (st.position.hasPixels && st.position.pixels != st.position.minScrollExtent) {
          st.position.jumpTo(st.position.minScrollExtent);
        }
      }
    }
    await t.pump(const Duration(milliseconds: 100));
  }

  /// يمرّر المحتوى كما يفعل الإصبع: dy سالب = للأعلى.
  Future<void> scrollBy(double dy, {Offset at = const Offset(206, 560)}) async {
    await t.dragFrom(at, Offset(0, dy));
    await settle(3);
  }

  /// يمرّر شريطاً أفقياً حتى يظهر عنصره.
  Future<void> revealInRow(Finder item, Finder row, {double dx = 120}) async {
    await t.dragUntilVisible(item, row, Offset(dx, 0), maxIteration: 40);
    await settle(2);
  }

  Future<void> tapFinder(Finder f, {int index = 0}) async {
    final at = f.at(index);
    if (f.evaluate().length <= index) throw StateError('لا عنصر مطابق (index=$index): $f');
    await t.ensureVisible(at);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(at);
    await settle(5);
  }

  Future<void> tapTooltip(String tip) => tapFinder(find.byTooltip(tip));
  Future<void> tapIcon(IconData icon, {int index = 0}) => tapFinder(find.byIcon(icon), index: index);

  /// يغلق أعلى نافذة/شاشة مفتوحة كما يفعل زر الرجوع.
  Future<void> closeTop() async {
    appNavigatorKey.currentState?.pop();
    await settle(4);
  }

  /// يغلق كل ما فُتح فوق الشاشة الرئيسية (نوافذ، لوحات، شاشات مدفوعة).
  Future<void> closeAll() async {
    final nav = appNavigatorKey.currentState;
    for (var i = 0; i < 6 && nav != null && nav.canPop(); i++) {
      nav.pop();
      await settle(2);
    }
  }

  /// يكتب في الحقل الذي يحمل هذه التسمية (labelText أو hintText).
  Future<void> typeInto(String label, String value) async {
    final f = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText == label || w.decoration?.labelText == label),
    );
    if (f.evaluate().isEmpty) {
      final have = find.byType(TextField).evaluate().map((e) => '${(e.widget as TextField).decoration?.labelText}|${(e.widget as TextField).decoration?.hintText}').join(' ¦ ');
      throw StateError('لا حقل بالتسمية "$label". الحقول الظاهرة: $have');
    }
    final field = t.widget<TextField>(f.first);
    final c = field.controller;
    if (c != null) {
      // بلا onChanged: بعض النوافذ تعيد البناء بسياق خارجي منتهٍ في وضع الـ debug، والنتيجة نفسها على الشاشة
      c.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    } else {
      await t.enterText(f.first, value);
    }
    await t.pump(const Duration(milliseconds: 150));
  }

  /// ينقر نصاً ظاهراً كما يفعل المستخدم (ويمرّر الشريط إن لزم).
  Finder textFinder(String text) {
    final exact = find.text(text);
    return exact.evaluate().isNotEmpty ? exact : find.textContaining(text);
  }

  Future<void> tapText(String text, {int index = 0}) => tapFinder(textFinder(text), index: index);

  /// ينقر تبويباً في شريط التبويبات من أعلى الصفحة.
  Future<void> tapTab(String label) async {
    await scrollToTop();
    await tapText(label);
  }

  Future<void> snap(String name, {List<Hot> hot = const [], String? note}) async {
    await settle(3);
    final dir = Directory(guideOut)..createSync(recursive: true);
    await t.runAsync(() async {
      final ro = boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await ro.toImage(pixelRatio: pixelRatio);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png').writeAsBytesSync(bd!.buffer.asUint8List());
    });
    final emoji = scanEmoji(boundary.currentContext!.findRenderObject()!, size, t.view.viewId);
    final targets = scanTargets(boundary.currentContext! as Element, size);
    manifest[name] = {
      'emoji': emoji,
      ...targets,
      'width': size.width,
      'height': size.height,
      'pixelRatio': pixelRatio,
      if (note != null) 'note': note,
      'hot': hot.map((h) => h.toJson()).toList(),
    };
    File('${dir.path}/manifest.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(manifest));
  }
}


/// نفس `MasjedApp` حرفياً (الموفّرات، الثيم، الاتجاه، `MainShell`) ومعها خط الإيموجي احتياطياً،
/// فالاختبار لا يملك خط إيموجي نظام فتظهر الرموز مربعات بدونه. لا يغيّر شيئاً من تصميم التطبيق.
class GuideApp extends StatelessWidget {
  const GuideApp({super.key});

  static ThemeData _withEmoji(ThemeData t) => t.copyWith(
        textTheme: t.textTheme.apply(fontFamilyFallback: const ['BlankEmoji']),
        primaryTextTheme: t.primaryTextTheme.apply(fontFamilyFallback: const ['BlankEmoji']),
      );

  @override
  Widget build(BuildContext context) {
    final dataService = sl<DataService>();
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionBloc>(create: (_) => sl<SessionBloc>()..add(const LoadSessionsEvent())),
        BlocProvider<ThemeCubit>(create: (_) => sl<ThemeCubit>()),
        BlocProvider<RecitationBloc>(create: (_) => sl<RecitationBloc>()),
        BlocProvider<TripsBloc>(create: (_) => sl<TripsBloc>()..add(const LoadTripsEvent())),
        BlocProvider<CoursesBloc>(create: (_) => sl<CoursesBloc>()..add(const LoadCoursesEvent())),
        BlocProvider<AttendanceBloc>(create: (_) => sl<AttendanceBloc>()),
        BlocProvider<RewardsBloc>(create: (_) => sl<RewardsBloc>()..add(const LoadRewardsEvent())),
        BlocProvider<CompetitionsBloc>(create: (_) => sl<CompetitionsBloc>()..add(const LoadCompetitionsEvent())),
      ],
      child: ChangeNotifierProvider<DataService>.value(
        value: dataService,
        child: Consumer<DataService>(
          builder: (context, data, _) {
            final mode = data.isDarkMode ? ThemeMode.dark : ThemeMode.light;
            return BlocBuilder<ThemeCubit, ThemeState>(
              builder: (context, themeState) {
                AppTypography.currentFontFamily = themeState.fontFamily;
                AppColors.currentPaletteId = themeState.paletteId;
                AppColors.isDarkMode = mode == ThemeMode.dark;
                return MaterialApp(
                  navigatorKey: appNavigatorKey,
                  debugShowCheckedModeBanner: false,
                  theme: _withEmoji(AppTheme.buildTheme(
                      isDark: false, paletteId: themeState.paletteId, fontFamily: themeState.fontFamily)),
                  darkTheme: _withEmoji(AppTheme.buildTheme(
                      isDark: true, paletteId: themeState.paletteId, fontFamily: themeState.fontFamily)),
                  themeMode: mode,
                  locale: const Locale('ar'),
                  supportedLocales: const [Locale('ar')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(themeState.fontScale)),
                    child: child!,
                  ),
                  home: !data.hasCompletedOnboarding ? const AppOnboardingScreen() : const MainShell(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
