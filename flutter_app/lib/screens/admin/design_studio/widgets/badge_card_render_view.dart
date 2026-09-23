import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/app_user_avatar.dart';
import '../models/badge_design_config.dart';

class BadgeCardRenderView extends StatelessWidget {
  final String name;
  final String roleLabel;
  final String code;
  final String mosqueName;
  final String? halaqaName;
  final String? sheikhName;
  final String? phone;
  final String? birthDate;
  final String? profileImageUrl;
  final BadgeDesignConfig config;
  final bool isDark;

  const BadgeCardRenderView({
    super.key,
    required this.name,
    required this.roleLabel,
    required this.code,
    required this.mosqueName,
    this.halaqaName,
    this.sheikhName,
    this.phone,
    this.birthDate,
    this.profileImageUrl,
    required this.config,
    this.isDark = false,
  });

  Color _getPrimaryColor() {
    switch (config.themeVariant) {
      case BadgeThemeVariant.ministerialGold:
        return AppColors.goldDark;
      case BadgeThemeVariant.quranicEmerald:
        return AppColors.emeraldPrimary;
      case BadgeThemeVariant.executiveDark:
        return const Color(0xFFC5A059);
    }
  }

  Color _getCardBg() {
    switch (config.themeVariant) {
      case BadgeThemeVariant.ministerialGold:
        return const Color(0xFFFCFBF9);
      case BadgeThemeVariant.quranicEmerald:
        return const Color(0xFFF7FAF8);
      case BadgeThemeVariant.executiveDark:
        return const Color(0xFF140D13);
    }
  }

  Color _getTextColor() {
    switch (config.themeVariant) {
      case BadgeThemeVariant.executiveDark:
        return Colors.white;
      default:
        return AppColors.obsidianEspresso;
    }
  }

  Color _getBorderColor() {
    switch (config.themeVariant) {
      case BadgeThemeVariant.ministerialGold:
        return AppColors.gold;
      case BadgeThemeVariant.quranicEmerald:
        return AppColors.emeraldPrimary;
      case BadgeThemeVariant.executiveDark:
        return AppColors.goldLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (config.orientation == BadgeOrientation.landscape) {
      return _buildLandscapeBadge(context);
    }
    return _buildPortraitBadge(context);
  }

  Widget _buildPortraitBadge(BuildContext context) {
    final primary = _getPrimaryColor();
    final cardBg = _getCardBg();
    final textColor = _getTextColor();
    final borderColor = _getBorderColor();
    final isThemeDark = config.themeVariant == BadgeThemeVariant.executiveDark;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Ministerial Ribbon & Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    isThemeDark ? const Color(0xFF2E1925) : primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                children: [
                  if (config.showMinistryHeader) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, color: AppColors.goldBright, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            config.customSubHeader,
                            style: AppTypography.font(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.mosque, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                mosqueName,
                                style: AppTypography.font(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.goldBright,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          roleLabel,
                          style: AppTypography.font(
                            fontSize: 10.5,
                            color: AppColors.obsidianEspresso,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Badge Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  if (config.showAvatar) ...[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.25),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: AppUserAvatar(
                              name: name,
                              imageUrl: profileImageUrl,
                              radius: 38,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Person Full Name
                  Text(
                    name,
                    style: AppTypography.font(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Halaqa and Sheikh Details
                  if (config.showHalaqa && halaqaName != null && halaqaName!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book, size: 13, color: primary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'الحلقة: $halaqaName',
                              style: AppTypography.font(fontSize: 11.5, color: primary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (config.showSheikh && sheikhName != null && sheikhName!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_pin, size: 13, color: primary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'المشرف: $sheikhName',
                              style: AppTypography.font(fontSize: 11.5, color: primary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (config.showPhone && phone != null && phone!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'هاتف: $phone',
                        style: AppTypography.font(fontSize: 11, color: isThemeDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],

                  if (config.showBirthDate && birthDate != null && birthDate!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'العمر: $birthDate سنة',
                        style: AppTypography.font(fontSize: 11, color: isThemeDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],

                  // QR Code Box
                  if (config.showQr) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QrImageView(
                            data: code,
                            version: QrVersions.auto,
                            size: 130,
                            gapless: true,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                          ),
                          if (config.showCode) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                code,
                                style: AppTypography.font(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.obsidianEspresso,
                                ).copyWith(letterSpacing: 1.1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (config.showCode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'كود الاعتماد: $code',
                        style: AppTypography.font(fontSize: 13, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Institutional Footer
            if (config.showFooterNote && config.footerNote.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isThemeDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3ECE1),
                  border: Border(top: BorderSide(color: borderColor.withValues(alpha: 0.3))),
                ),
                child: Text(
                  config.footerNote,
                  style: AppTypography.font(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isThemeDark ? Colors.white60 : AppColors.goldBrownText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeBadge(BuildContext context) {
    final primary = _getPrimaryColor();
    final cardBg = _getCardBg();
    final textColor = _getTextColor();
    final borderColor = _getBorderColor();
    final isThemeDark = config.themeVariant == BadgeThemeVariant.executiveDark;

    return Container(
      width: 440,
      height: 260,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    isThemeDark ? const Color(0xFF2E1925) : primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (config.showMinistryHeader)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.account_balance, color: AppColors.goldBright, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              config.customSubHeader,
                              style: AppTypography.font(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mosque, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        mosqueName,
                        style: AppTypography.font(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Right Details
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              if (config.showAvatar) ...[
                                AppUserAvatar(name: name, imageUrl: profileImageUrl, radius: 22),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: AppTypography.font(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        roleLabel,
                                        style: AppTypography.font(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (config.showHalaqa && halaqaName != null && halaqaName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'الحلقة: $halaqaName',
                                style: AppTypography.font(
                                  fontSize: 11,
                                  color: isThemeDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (config.showSheikh && sheikhName != null && sheikhName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'المشرف: $sheikhName',
                                style: AppTypography.font(
                                  fontSize: 11,
                                  color: isThemeDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (config.showPhone && phone != null && phone!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'هاتف: $phone',
                                style: AppTypography.font(
                                  fontSize: 11,
                                  color: isThemeDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (config.showBirthDate && birthDate != null && birthDate!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'العمر: $birthDate سنة',
                                style: AppTypography.font(
                                  fontSize: 11,
                                  color: isThemeDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (!config.showQr && config.showCode) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'كود الاعتماد: $code',
                                style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Left QR Code & Code Badge
                    if (config.showQr) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: code,
                              version: QrVersions.auto,
                              size: 100,
                              gapless: true,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(2),
                            ),
                            if (config.showCode) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  code,
                                  style: AppTypography.font(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.obsidianEspresso,
                                  ).copyWith(letterSpacing: 1.0),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom Strip
            if (config.showFooterNote && config.footerNote.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: isThemeDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3ECE1),
                child: Text(
                  config.footerNote,
                  style: AppTypography.font(fontSize: 8.5, color: isThemeDark ? Colors.white60 : Colors.black54),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
