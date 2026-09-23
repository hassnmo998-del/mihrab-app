import 'package:flutter/foundation.dart';

import '../core/utils/access_code_generator.dart';

class Mosque {
  final String id;
  final String name;
  final String city;
  final String? address;
  final String? phone;

  /// 'male' or 'female'. A 'female' mosque is a fully separate record with its
  /// own id and its own access code, so every `mosqueId` scoped query in the app
  /// isolates the two branches without needing a gender clause.
  final String gender;
  final String accessCode;

  /// Single-use provisioning token (`WMV-…`) the men's administration issues so
  /// the women's administration can create its own branch. It is **not** a login
  /// credential for this mosque and is cleared once redeemed.
  final String? womenAccessCode;

  /// Id of the women's branch provisioned from this mosque, once it exists.
  final String? womenBranchId;

  /// For a women's branch: the men's mosque that provisioned it.
  final String? parentMosqueId;

  /// Stored cashier code. Legacy rows fall back to the derived code so badges
  /// printed before the hardening keep working.
  final String? cashierAccessCode;

  final double latitude;
  final double longitude;
  final String? donationImageUrl;
  final String? donationAccountName;
  final String? donationAccountNumber;
  final String? donationDescription;
  final bool isDonationEnabled;

  Mosque({
    required this.id,
    required this.name,
    required this.city,
    this.address,
    this.phone,
    required this.gender,
    required this.accessCode,
    this.womenAccessCode,
    this.womenBranchId,
    this.parentMosqueId,
    this.cashierAccessCode,
    this.latitude = 33.5138,
    this.longitude = 36.2765,
    this.donationImageUrl,
    this.donationAccountName,
    this.donationAccountNumber,
    this.donationDescription,
    this.isDonationEnabled = true,
  });

  String get neighborhood => city;
  String get genderBranch => gender;

  bool get isWomenSection => gender == 'female';

  /// A women's branch created through the provisioning flow (as opposed to a
  /// legacy standalone female compound registered before that flow existed).
  bool get isLinkedWomenBranch =>
      isWomenSection && (parentMosqueId?.isNotEmpty ?? false);

  bool get hasWomenBranch => womenBranchId?.isNotEmpty ?? false;

  /// The live provisioning token, or null when nothing is pending: no token was
  /// minted, it was already redeemed, or the stored value is a legacy derivable
  /// `WM-` code.
  String? get womenProvisionToken {
    final token = womenAccessCode?.trim();
    if (token == null || token.isEmpty) return null;
    if (!AccessCodeGenerator.isWomenProvisionToken(token)) return null;
    return token.toUpperCase();
  }

  /// A token is outstanding and no branch exists yet: redeeming it creates the
  /// women's administration. When a branch already exists, an outstanding token
  /// hands that existing branch over instead of creating a second one.
  bool get isAwaitingWomenBranch =>
      womenProvisionToken != null && !hasWomenBranch;

  String get effectiveCashierCode {
    final stored = cashierAccessCode?.trim();
    if (stored != null && stored.isNotEmpty) return stored.toUpperCase();
    return 'CSH-${accessCode.replaceAll("MSQ-", "")}';
  }

  bool get hasActiveDonation =>
      isDonationEnabled &&
      ((donationAccountNumber?.isNotEmpty ?? false) ||
          (donationImageUrl?.isNotEmpty ?? false));

  /// Drops empty values and legacy `WM-` tokens, which are computable from the
  /// mosque access code and must never be honoured again.
  static String? _sanitizeWomenToken(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    if (AccessCodeGenerator.isLegacyWomenCode(value)) return null;
    return value.toUpperCase();
  }

  static String? _nullIfEmpty(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  factory Mosque.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final rawCode =
        json['access_code']?.toString() ?? json['accessCode']?.toString();

    // Never synthesise a code from the id: ids travel with every event and
    // student row, so a derived code would be guessable by anyone who sees one.
    final code = (rawCode != null && rawCode.trim().isNotEmpty)
        ? rawCode.trim()
        : '';
    if (code.isEmpty && rawId.isNotEmpty) {
      debugPrint(
        'ℹ️ المسجد ($rawId) بلا كود اعتماد مخزَّن — يحتاج إعادة إصدار من الإدارة.',
      );
    }

    return Mosque(
      id: rawId,
      name: json['name'] ?? '',
      city: json['city'] ?? json['neighborhood'] ?? 'دمشق',
      address: json['address'],
      phone: json['phone'],
      gender: json['gender'] ?? json['gender_branch'] ?? 'male',
      accessCode: code,
      womenAccessCode: _sanitizeWomenToken(
        json['women_access_code'] ?? json['womenAccessCode'],
      ),
      womenBranchId: _nullIfEmpty(
        json['women_branch_id'] ?? json['womenBranchId'],
      ),
      parentMosqueId: _nullIfEmpty(
        json['parent_mosque_id'] ?? json['parentMosqueId'],
      ),
      cashierAccessCode: _nullIfEmpty(
        json['cashier_access_code'] ?? json['cashierAccessCode'],
      ),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 33.5138,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 36.2765,
      donationImageUrl: json['donation_image_url'] ?? json['donationImageUrl'],
      donationAccountName:
          json['donation_account_name'] ?? json['donationAccountName'],
      donationAccountNumber:
          json['donation_account_number'] ?? json['donationAccountNumber'],
      donationDescription:
          json['donation_description'] ?? json['donationDescription'],
      isDonationEnabled:
          json['is_donation_enabled'] ?? json['isDonationEnabled'] ?? true,
    );
  }

  /// Columns added by the branch-isolation migration. The remote data source
  /// retries without them when the migration has not been applied yet.
  static const Set<String> branchColumns = {
    'women_branch_id',
    'parent_mosque_id',
    'cashier_access_code',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'address': address,
    'phone': phone,
    'gender': gender,
    'access_code': accessCode,
    'women_access_code': womenAccessCode,
    'women_branch_id': womenBranchId,
    'parent_mosque_id': parentMosqueId,
    'cashier_access_code': cashierAccessCode,
    'latitude': latitude,
    'longitude': longitude,
    'donation_image_url': donationImageUrl,
    'donation_account_name': donationAccountName,
    'donation_account_number': donationAccountNumber,
    'donation_description': donationDescription,
    'is_donation_enabled': isDonationEnabled,
  };

  Mosque copyWith({
    String? id,
    String? name,
    String? city,
    String? address,
    String? phone,
    String? gender,
    String? accessCode,
    String? womenAccessCode,
    String? womenBranchId,
    String? parentMosqueId,
    String? cashierAccessCode,
    double? latitude,
    double? longitude,
    String? donationImageUrl,
    String? donationAccountName,
    String? donationAccountNumber,
    String? donationDescription,
    bool? isDonationEnabled,
    bool clearWomenAccessCode = false,
    bool clearWomenBranch = false,
  }) {
    return Mosque(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      accessCode: accessCode ?? this.accessCode,
      womenAccessCode: clearWomenAccessCode
          ? null
          : (womenAccessCode ?? this.womenAccessCode),
      womenBranchId: clearWomenBranch
          ? null
          : (womenBranchId ?? this.womenBranchId),
      parentMosqueId: parentMosqueId ?? this.parentMosqueId,
      cashierAccessCode: cashierAccessCode ?? this.cashierAccessCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      donationImageUrl: donationImageUrl ?? this.donationImageUrl,
      donationAccountName: donationAccountName ?? this.donationAccountName,
      donationAccountNumber:
          donationAccountNumber ?? this.donationAccountNumber,
      donationDescription: donationDescription ?? this.donationDescription,
      isDonationEnabled: isDonationEnabled ?? this.isDonationEnabled,
    );
  }
}
