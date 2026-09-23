import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Centralized Luxury User Avatar.
/// Supports local device images, remote network images, and rich Arabic typographic fallbacks.
class AppUserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String? role;
  final double radius;
  final Border? border;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppUserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.role,
    this.radius = 22,
    this.border,
    this.onTap,
    this.backgroundColor,
  });

  String _getInitials(String str) {
    final parts = str.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'م';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1);
    }
    return '${parts[0][0]}${parts[1][0]}';
  }

  LinearGradient _getRoleGradient() {
    switch (role) {
      case 'sheikh':
        return const LinearGradient(
          colors: [Color(0xFF153B30), Color(0xFF1E5242), Color(0xFF439E81)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        );
      case 'mosque_admin':
        return AppColors.sunsetTwilightGradient;
      case 'student':
      default:
        return const LinearGradient(
          colors: [Color(0xFF2C1420), Color(0xFFC86D3B), Color(0xFFDE935E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarContent;

    final hasValidUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    bool isLocalFile = false;
    File? localFile;

    if (hasValidUrl) {
      final trimmed = imageUrl!.trim();
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        localFile = File(trimmed);
        isLocalFile = localFile.existsSync();
      }
    }

    if (isLocalFile && localFile != null) {
      avatarContent = Image.file(
        localFile,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitials(),
      );
    } else if (hasValidUrl && (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'))) {
      avatarContent = Image.network(
        imageUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitials(),
      );
    } else {
      avatarContent = _buildInitials();
    }

    final avatarCircle = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border ??
            Border.all(
              color: AppColors.goldBright.withValues(alpha: 0.6),
              width: 1.5,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarCircle,
      );
    }

    return avatarCircle;
  }

  Widget _buildInitials() {
    final initials = _getInitials(name);
    final fontSize = (radius * 0.85).clamp(9.0, 22.0);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: backgroundColor == null ? _getRoleGradient() : null,
        color: backgroundColor,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: fontSize,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
