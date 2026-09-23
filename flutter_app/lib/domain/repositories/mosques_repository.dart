import '../../models/models.dart';

/// Contract for Mosques management and women's-branch provisioning.
abstract class MosquesRepository {
  List<Mosque> getMosques({String? gender});

  /// Mosques a viewer of [viewerBranch] is allowed to see. A male or anonymous
  /// viewer never sees a women's branch; a female viewer sees both.
  List<Mosque> getMosquesForViewer(String viewerBranch);

  Mosque? getMosqueById(String id);

  Mosque addMosque({
    required String name,
    required String address,
    required String city,
    required String gender,
    String? phone,
    double? latitude,
    double? longitude,
    String? parentMosqueId,
  });

  void updateMosque({
    required String id,
    required String name,
    required String address,
    required String city,
    String? phone,
    double? latitude,
    double? longitude,
  });

  void deleteMosque(String mosqueId);

  /// Mints a fresh single-use `WMV-` token on [mosqueId] and returns it, or null
  /// if the mosque does not exist or is itself a women's branch.
  String? issueWomenProvisionToken(String mosqueId);

  /// The men's mosque holding [token] as its outstanding provisioning token.
  Mosque? findMosqueByProvisionToken(String token);

  /// Creates the isolated women's branch for [parentMosqueId] and consumes the
  /// token. Returns null when the token no longer matches or a branch exists.
  Mosque? createWomenBranch({
    required String parentMosqueId,
    required String token,
    required String name,
    required String city,
    required String address,
    String? phone,
    double? latitude,
    double? longitude,
  });

  /// Consumes an outstanding token that pointed at an existing branch, handing
  /// that branch to whoever redeemed it. Returns the branch mosque.
  Mosque? consumeProvisionTokenForExistingBranch({
    required String parentMosqueId,
    required String token,
  });
}
