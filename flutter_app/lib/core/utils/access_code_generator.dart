import 'dart:math';

/// Cryptographically seeded factory for every branch-level access code.
///
/// Codes are deliberately **not derivable from one another**: holding a mosque
/// access code must never reveal the women's provisioning token nor the cashier
/// code, and vice versa. Before this factory existed the women's code was just
/// `MSQ-1234` → `WM-1234`, which meant either side could compute the other and
/// log into the other branch. Every code is now minted from [Random.secure]
/// over an alphabet stripped of visually ambiguous glyphs (I, O, 0, 1) so the
/// codes stay readable when printed on a badge and typed by hand.
class AccessCodeGenerator {
  AccessCodeGenerator._();

  static const String mosquePrefix = 'MSQ-';
  static const String womenProvisionPrefix = 'WMV-';
  static const String cashierPrefix = 'CSH-';

  /// Single-use codes the super admin issues to open a new mosque registration.
  static const String registrationPrefix = 'REG-';

  /// Pre-hardening women's codes, derivable from the mosque code by prefix swap.
  static const String legacyWomenPrefix = 'WM-';

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _bodyLength = 8;

  static final Random _random = Random.secure();

  static String _body([int length = _bodyLength]) => String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
    ),
  );

  /// Access code for a mosque administration (men's branch or women's branch).
  static String mosqueCode() => '$mosquePrefix${_body()}';

  /// Single-use token the men's administration hands to the women's
  /// administration so it can provision its own isolated branch.
  static String womenProvisionToken() => '$womenProvisionPrefix${_body()}';

  static String cashierCode() => '$cashierPrefix${_body()}';

  /// Entity identifier that carries no information about any access code.
  static String entityId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${_body(4)}';

  /// `WM-` tokens are refused on sight: they are computable from the mosque
  /// access code, so the admin must mint a fresh [womenProvisionToken] instead.
  static bool isLegacyWomenCode(String code) =>
      code.trim().toUpperCase().startsWith(legacyWomenPrefix);

  static bool isWomenProvisionToken(String code) =>
      code.trim().toUpperCase().startsWith(womenProvisionPrefix);

  /// Registration codes are never login credentials: they unlock the new
  /// mosque form, so every scanner must route them there instead of login.
  static bool isRegistrationToken(String code) =>
      code.trim().toUpperCase().startsWith(registrationPrefix);
}
