import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حالة زر «؟» ونافذة التعريف الأولى، محفوظة على الجهاز.
///
/// - [opened]: فتح المستخدم شاشة التعلّم مرة على الأقل (قبلها يومض الزر ليلفت النظر).
/// - [coachSeen]: ظهرت له نافذة التعريف (أو تخطّاها)، فلا تظهر ثانية. من يحدّث إلى
///   هذا الإصدار لا مفتاح عنده فتظهر له مرة واحدة، كمن يثبّت التطبيق لأول مرة.
/// - [unreadReply]: ردّ جديد من المطوّر لم يُقرأ بعد (يومض الزر من جديد).
class HelpState extends ChangeNotifier {
  HelpState._();

  static final HelpState instance = HelpState._();

  static const String openedKey = 'help_opened_v1';
  static const String coachKey = 'help_coach_seen_v1';

  bool loaded = false;
  bool opened = false;
  bool coachSeen = false;
  bool unreadReply = false;

  /// لا يومض قبل أن تُقرأ الحالة من الجهاز (فلا وميض كاذب عند الإقلاع).
  bool get shouldPulse => loaded && (!opened || unreadReply);

  /// نافذة التعريف: بعد الإقلاع فقط ولمرة واحدة.
  bool get shouldShowCoach => loaded && !coachSeen;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      opened = prefs.getBool(openedKey) ?? false;
      coachSeen = prefs.getBool(coachKey) ?? false;
    } catch (_) {
      // بلا تخزين: نعدّه رآها كي لا نزعجه في كل فتحة
      opened = true;
      coachSeen = true;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> markOpened() async {
    if (opened) return;
    opened = true;
    notifyListeners();
    await _save(openedKey);
  }

  Future<void> markCoachSeen() async {
    if (coachSeen) return;
    coachSeen = true;
    notifyListeners();
    await _save(coachKey);
  }

  void setUnreadReply(bool value) {
    if (unreadReply == value) return;
    unreadReply = value;
    notifyListeners();
  }

  Future<void> _save(String key) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, true);
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTest({bool loaded = false, bool opened = false, bool coachSeen = false, bool unreadReply = false}) {
    this.loaded = loaded;
    this.opened = opened;
    this.coachSeen = coachSeen;
    this.unreadReply = unreadReply;
    notifyListeners();
  }
}
