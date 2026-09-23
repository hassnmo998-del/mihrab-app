import 'mosque.dart';

/// What a scanned `WMV-` token resolves to.
///
/// The women's administration can only ever come into existence by scanning a
/// token issued from an existing men's administration, so this offer is the one
/// and only gateway into a women's branch.
class WomenBranchProvisionOffer {
  /// The men's mosque that issued the token.
  final Mosque parentMosque;

  final String token;

  /// True when the branch already exists and this token hands it over (a
  /// recovery re-issue) instead of creating a new one.
  final bool isHandover;

  const WomenBranchProvisionOffer({
    required this.parentMosque,
    required this.token,
    required this.isHandover,
  });

  String get suggestedBranchName => 'القسم النسائي - ${parentMosque.name}';
}
