import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';
import '../design_studio/models/badge_design_config.dart';
import '../design_studio/models/poster_design_config.dart';
import '../design_studio/services/design_export_service.dart';
import '../design_studio/widgets/badge_card_render_view.dart';
import '../design_studio/widgets/batch_badge_sheet_dialog.dart';
import '../design_studio/widgets/honor_poster_render_view.dart';

class AdminDesignStudioTab extends StatefulWidget {
  final Mosque mosque;
  final bool isDark;

  const AdminDesignStudioTab({
    super.key,
    required this.mosque,
    this.isDark = false,
  });

  @override
  State<AdminDesignStudioTab> createState() => _AdminDesignStudioTabState();
}

class _AdminDesignStudioTabState extends State<AdminDesignStudioTab> {
  // 0: Badges Studio, 1: Honor Posters Studio
  int _studioMode = 0;

  // GlobalKeys for RepaintBoundary
  final GlobalKey _badgeBoundaryKey = GlobalKey();
  final GlobalKey _posterBoundaryKey = GlobalKey();

  // --- BADGE STUDIO STATE ---
  BadgeDesignConfig _badgeConfig = const BadgeDesignConfig();
  String _badgeScope = 'single_student'; // single_student, full_halaqa, all_students, single_sheikh, all_sheikhs
  String? _selectedStudentId;
  String? _selectedSheikhId;
  String? _selectedHalaqaId;

  // --- POSTER STUDIO STATE ---
  PosterDesignConfig _posterConfig = const PosterDesignConfig();
  String _posterFilterScope = 'all_mosque'; // all_mosque, specific_halaqa, specific_competition
  String? _posterHalaqaId;
  String? _posterCompetitionId;
  String? _spotlightStudentId;
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _posterMinistryHeaderController;
  late TextEditingController _posterStampTextController;
  late TextEditingController _badgeSubHeaderController;
  late TextEditingController _badgeFooterNoteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _posterConfig.title);
    _subtitleController = TextEditingController(text: _posterConfig.subtitle);
    _posterMinistryHeaderController = TextEditingController(text: _posterConfig.ministryHeader);
    _posterStampTextController = TextEditingController(text: _posterConfig.stampText);
    _badgeSubHeaderController = TextEditingController(text: _badgeConfig.customSubHeader);
    _badgeFooterNoteController = TextEditingController(text: _badgeConfig.footerNote);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _posterMinistryHeaderController.dispose();
    _posterStampTextController.dispose();
    _badgeSubHeaderController.dispose();
    _badgeFooterNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final students = data.getStudents(mosqueId: widget.mosque.id);
    final sheikhs = data.getSheikhs(mosqueId: widget.mosque.id);
    final halaqat = data.getHalaqat(mosqueId: widget.mosque.id);
    final competitions = data.getCompetitions(mosqueId: widget.mosque.id);

    // Ensure defaults
    if (_selectedStudentId == null && students.isNotEmpty) {
      _selectedStudentId = students.first.id;
    }
    if (_selectedSheikhId == null && sheikhs.isNotEmpty) {
      _selectedSheikhId = sheikhs.first.id;
    }
    if (_selectedHalaqaId == null && halaqat.isNotEmpty) {
      _selectedHalaqaId = halaqat.first.id;
    }
    if (_spotlightStudentId == null && students.isNotEmpty) {
      _spotlightStudentId = students.first.id;
    }
    if (_posterHalaqaId == null && halaqat.isNotEmpty) {
      _posterHalaqaId = halaqat.first.id;
    }
    if (_posterCompetitionId == null && competitions.isNotEmpty) {
      _posterCompetitionId = competitions.first.id;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Institutional Banner Header
          _buildInstitutionalHeader(isDark),
          const SizedBox(height: 16),

          // Studio Mode Switcher
          _buildModeSegmentedSelector(isDark),
          const SizedBox(height: 20),

          // Studio View
          if (_studioMode == 0)
            _buildBadgeStudioContent(
              students: students,
              sheikhs: sheikhs,
              halaqat: halaqat,
              isDark: isDark,
              primaryColor: primaryColor,
            )
          else
            _buildPosterStudioContent(
              students: students,
              halaqat: halaqat,
              competitions: competitions,
              isDark: isDark,
              primaryColor: primaryColor,
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // Top Headers & Selectors
  // =========================================================================

  Widget _buildInstitutionalHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF281423), const Color(0xFF140D13)]
              : [AppColors.goldSoftBg, const Color(0xFFF7EFE1)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Icon(Icons.palette_outlined, color: AppColors.goldDark, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'مركز التصاميم والطباعة المعتمدة',
                      style: AppTypography.font(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.obsidianEspresso,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '',
                        style: AppTypography.font(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'منظومة متكاملة لإنتاج باجات الهوية الشخصية وبوسترات التكريم والنشر الاجتماعي بدقة طباعة فائقة',
                  style: AppTypography.font(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegmentedSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231822) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              title: 'استوديو بطاقات وهويات الاعتماد',
              icon: Icons.badge_outlined,
              isSelected: _studioMode == 0,
              onTap: () => setState(() => _studioMode = 0),
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              title: 'استوديو لوحات الشرف وبوسترات التكريم',
              icon: Icons.emoji_events_outlined,
              isSelected: _studioMode == 1,
              onTap: () => setState(() => _studioMode = 1),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.goldDark : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.goldBrownText)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: AppTypography.font(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.obsidianEspresso)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SUB-STUDIO 1: BADGE STUDIO
  // =========================================================================

  Widget _buildBadgeStudioContent({
    required List<Student> students,
    required List<Sheikh> sheikhs,
    required List<Halaqa> halaqat,
    required bool isDark,
    required Color primaryColor,
  }) {
    // Determine active preview person
    Student? previewStudent;
    Sheikh? previewSheikh;
    String previewName = 'اسم الشخص';
    String previewRole = 'طالب مسجل';
    String previewCode = 'STD-0000';
    String? previewHalaqa;
    String? previewSheikhName;
    String? previewPhone;
    String? previewBirthDate;
    String? previewImage;

    if (_badgeScope == 'single_sheikh' || _badgeScope == 'all_sheikhs') {
      previewSheikh = sheikhs.where((s) => s.id == _selectedSheikhId).firstOrNull ?? sheikhs.firstOrNull;
      if (previewSheikh != null) {
        previewName = previewSheikh.fullName;
        previewRole = 'محفّظ / معلّم';
        previewCode = previewSheikh.code;
        previewPhone = previewSheikh.phone;
        previewImage = previewSheikh.profileImageUrl;
      }
    } else {
      if (_badgeScope == 'full_halaqa') {
        final halaqaStudents = students.where((s) => s.halaqaId == _selectedHalaqaId).toList();
        previewStudent = halaqaStudents.firstOrNull ?? students.firstOrNull;
      } else {
        previewStudent = students.where((s) => s.id == _selectedStudentId).firstOrNull ?? students.firstOrNull;
      }

      if (previewStudent != null) {
        previewName = previewStudent.fullName;
        previewRole = 'طالب بالمسجد';
        previewCode = previewStudent.code;
        previewPhone = previewStudent.phone;
        previewBirthDate = previewStudent.birthDate;
        previewImage = previewStudent.profileImageUrl;
        final h = halaqat.where((x) => x.id == previewStudent!.halaqaId).firstOrNull;
        previewHalaqa = h?.name;
        if (h?.sheikhId != null) {
          final sh = sheikhs.where((s) => s.id == h!.sheikhId).firstOrNull;
          previewSheikhName = sh?.fullName;
        }
      }
    }

    final isBatch = _badgeScope == 'all_students' ||
        _badgeScope == 'full_halaqa' ||
        _badgeScope == 'all_sheikhs';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controls Column
            Expanded(
              flex: isWide ? 5 : 0,
              child: _buildBadgeControls(
                students: students,
                sheikhs: sheikhs,
                halaqat: halaqat,
                isDark: isDark,
              ),
            ),
            if (isWide) const SizedBox(width: 20) else const SizedBox(height: 24),

            // Live Preview & Action Buttons Column
            Expanded(
              flex: isWide ? 6 : 0,
              child: Column(
                children: [
                  // Preview Canvas
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF191218) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'المعاينة الحية للبطاقة',
                              style: AppTypography.font(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _badgeConfig.orientation == BadgeOrientation.portrait ? 'طولي (صدر)' : 'عرضي (جيب)',
                                style: AppTypography.font(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.goldDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: RepaintBoundary(
                            key: _badgeBoundaryKey,
                            child: BadgeCardRenderView(
                              name: previewName,
                              roleLabel: previewRole,
                              code: previewCode,
                              mosqueName: widget.mosque.name,
                              halaqaName: previewHalaqa,
                              sheikhName: previewSheikhName,
                              phone: previewPhone,
                              birthDate: previewBirthDate,
                              profileImageUrl: previewImage,
                              config: _badgeConfig,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      // Direct Single Share
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('مشاركة البطاقة (WhatsApp)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.terracottaPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            DesignExportService.shareDesign(
                              context: context,
                              boundaryKey: _badgeBoundaryKey,
                              fileNamePrefix: 'badge_$previewCode',
                              shareMessage: '''
بطاقة الاعتماد الرسمية الصادرة عن ${widget.mosque.name}:
الاسم: $previewName
الدور: $previewRole
الكود: $previewCode
''',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Save PNG
                      IconButton.filledTonal(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'حفظ كصورة عالية الدقة',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          DesignExportService.saveToDevice(
                            context: context,
                            boundaryKey: _badgeBoundaryKey,
                            fileNamePrefix: 'badge_$previewCode',
                          );
                        },
                      ),
                    ],
                  ),

                  // Batch Print Trigger if applicable
                  if (isBatch) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined, size: 20),
                        label: Text(
                          _badgeScope == 'all_students'
                              ? 'طباعة مجمعة لجميع طلاب المسجد (${students.length} بطاقة)'
                              : _badgeScope == 'full_halaqa'
                                  ? 'طباعة مجمعة لطلاب الحلقة المحددة'
                                  : 'طباعة مجمعة لجميع مشايخ المسجد (${sheikhs.length} بطاقة)',
                          style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.gold, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          _openBatchSheetDialog(students, sheikhs, halaqat);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openBatchSheetDialog(List<Student> students, List<Sheikh> sheikhs, List<Halaqa> halaqat) {
    List<BatchItemData> items = [];

    if (_badgeScope == 'all_sheikhs') {
      items = sheikhs.map((s) {
        return BatchItemData(
          name: s.fullName,
          roleLabel: 'محفّظ / معلّم',
          code: s.code,
          phone: s.phone,
          profileImageUrl: s.profileImageUrl,
        );
      }).toList();
    } else {
      List<Student> targetStudents = students;
      if (_badgeScope == 'full_halaqa') {
        targetStudents = students.where((s) => s.halaqaId == _selectedHalaqaId).toList();
      }
      items = targetStudents.map((st) {
        final h = halaqat.where((x) => x.id == st.halaqaId).firstOrNull;
        final sh = h?.sheikhId != null ? sheikhs.where((x) => x.id == h!.sheikhId).firstOrNull : null;
        return BatchItemData(
          name: st.fullName,
          roleLabel: 'طالب بالمسجد',
          code: st.code,
          halaqaName: h?.name,
          sheikhName: sh?.fullName,
          phone: st.phone,
          birthDate: st.birthDate,
          profileImageUrl: st.profileImageUrl,
        );
      }).toList();
    }

    showDialog(
      context: context,
      builder: (ctx) => BatchBadgeSheetDialog(
        mosqueName: widget.mosque.name,
        title: 'مسرد الطباعة المجمعة للبطاقات',
        items: items,
        config: _badgeConfig,
      ),
    );
  }

  Widget _buildBadgeControls({
    required List<Student> students,
    required List<Sheikh> sheikhs,
    required List<Halaqa> halaqat,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231822) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'نطاق إصدار البطاقة',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Scope Dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _badgeScope,
            decoration: _inputDecoration('الفئة المستهدفة', isDark),
            items: const [
              DropdownMenuItem(value: 'single_student', child: Text('طالب محدد')),
              DropdownMenuItem(value: 'full_halaqa', child: Text('طلاب حلقة كاملة')),
              DropdownMenuItem(value: 'all_students', child: Text('جميع طلاب المسجد (طباعة جماعية)')),
              DropdownMenuItem(value: 'single_sheikh', child: Text('شيخ / معلّم محدد')),
              DropdownMenuItem(value: 'all_sheikhs', child: Text('جميع شيوخ ومعلمات المسجد')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _badgeScope = val);
            },
          ),
          const SizedBox(height: 12),

          // Sub-selectors based on scope
          if (_badgeScope == 'single_student') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedStudentId,
              decoration: _inputDecoration('اختر الطالب', isDark),
              items: students.map((s) {
                return DropdownMenuItem(value: s.id, child: Text(s.fullName));
              }).toList(),
              onChanged: (val) => setState(() => _selectedStudentId = val),
            ),
            const SizedBox(height: 12),
          ],

          if (_badgeScope == 'full_halaqa') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedHalaqaId,
              decoration: _inputDecoration('اختر الحلقة القرآنية', isDark),
              items: halaqat.map((h) {
                return DropdownMenuItem(value: h.id, child: Text(h.name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedHalaqaId = val),
            ),
            const SizedBox(height: 12),
          ],

          if (_badgeScope == 'single_sheikh') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedSheikhId,
              decoration: _inputDecoration('اختر الشيخ / المعلم', isDark),
              items: sheikhs.map((s) {
                return DropdownMenuItem(value: s.id, child: Text(s.fullName));
              }).toList(),
              onChanged: (val) => setState(() => _selectedSheikhId = val),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 24),

          // Orientation Selector
          Text(
            'توجيه وحجم البطاقة',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('طولي (تعليق صدر)')),
                  selected: _badgeConfig.orientation == BadgeOrientation.portrait,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _badgeConfig = _badgeConfig.copyWith(orientation: BadgeOrientation.portrait);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('عرضي (محفظة جيب)')),
                  selected: _badgeConfig.orientation == BadgeOrientation.landscape,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _badgeConfig = _badgeConfig.copyWith(orientation: BadgeOrientation.landscape);
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Theme Variant
          Text(
            'النمط والقالب الوزاري',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildThemeChip(
                label: 'ذهبي ملكي',
                isSelected: _badgeConfig.themeVariant == BadgeThemeVariant.ministerialGold,
                color: AppColors.gold,
                onTap: () => setState(() {
                  _badgeConfig = _badgeConfig.copyWith(themeVariant: BadgeThemeVariant.ministerialGold);
                }),
              ),
              const SizedBox(width: 6),
              _buildThemeChip(
                label: 'زمردي قرآني',
                isSelected: _badgeConfig.themeVariant == BadgeThemeVariant.quranicEmerald,
                color: AppColors.emeraldPrimary,
                onTap: () => setState(() {
                  _badgeConfig = _badgeConfig.copyWith(themeVariant: BadgeThemeVariant.quranicEmerald);
                }),
              ),
              const SizedBox(width: 6),
              _buildThemeChip(
                label: 'كحلي داكن',
                isSelected: _badgeConfig.themeVariant == BadgeThemeVariant.executiveDark,
                color: const Color(0xFF231822),
                onTap: () => setState(() {
                  _badgeConfig = _badgeConfig.copyWith(themeVariant: BadgeThemeVariant.executiveDark);
                }),
              ),
            ],
          ),

          const Divider(height: 24),

          // Custom Titles for Badge
          Text(
            'نصوص وعناوين البطاقة',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _badgeSubHeaderController,
            decoration: _inputDecoration('الترويسة الوزارية / المؤسسية (أعلى البطاقة)', isDark),
            onChanged: (val) => setState(() => _badgeConfig = _badgeConfig.copyWith(customSubHeader: val)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _badgeFooterNoteController,
            decoration: _inputDecoration('نص الحاشية السفلية للاعتماد (أسفل البطاقة)', isDark),
            onChanged: (val) => setState(() => _badgeConfig = _badgeConfig.copyWith(footerNote: val)),
          ),

          const Divider(height: 24),

          // Toggles
          Text(
            'تخصيص الحقول والعناصر الظاهرة',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          _buildSwitchTile('إظهار الترويسة الوزارية الرسمية', _badgeConfig.showMinistryHeader, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showMinistryHeader: v));
          }),
          _buildSwitchTile('إظهار الحاشية السفلية للاعتماد', _badgeConfig.showFooterNote, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showFooterNote: v));
          }),
          _buildSwitchTile('رمز الاستجابة السريع (QR Code)', _badgeConfig.showQr, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showQr: v));
          }),
          _buildSwitchTile('الكود المعرف المعتمد (STD / SHK)', _badgeConfig.showCode, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showCode: v));
          }),
          _buildSwitchTile('اسم الحلقة القرآنية', _badgeConfig.showHalaqa, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showHalaqa: v));
          }),
          _buildSwitchTile('اسم الشيخ المشرف', _badgeConfig.showSheikh, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showSheikh: v));
          }),
          _buildSwitchTile('الصورة الشخصية للباج', _badgeConfig.showAvatar, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showAvatar: v));
          }),
          _buildSwitchTile('رقم هاتف التواصل', _badgeConfig.showPhone, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showPhone: v));
          }),
          _buildSwitchTile('تاريخ الميلاد / العمر', _badgeConfig.showBirthDate, (v) {
            setState(() => _badgeConfig = _badgeConfig.copyWith(showBirthDate: v));
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // SUB-STUDIO 2: POSTER STUDIO
  // =========================================================================

  Widget _buildPosterStudioContent({
    required List<Student> students,
    required List<Halaqa> halaqat,
    required List<Competition> competitions,
    required bool isDark,
    required Color primaryColor,
  }) {
    // 1. Filter students according to poster settings
    List<Student> filteredStudents = List.from(students);

    if (_posterFilterScope == 'specific_halaqa' && _posterHalaqaId != null) {
      filteredStudents = filteredStudents.where((s) => s.halaqaId == _posterHalaqaId).toList();
    }

    // Sort by points descending
    filteredStudents.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    // If single spotlight chosen, select that student specifically
    if (_posterConfig.layoutType == PosterLayoutType.singleSpotlight) {
      filteredStudents = filteredStudents.where((s) => s.id == _spotlightStudentId).toList();
    }

    // Map to RankedStudentEntry
    List<RankedStudentEntry> rankedEntries = [];
    for (int i = 0; i < filteredStudents.length; i++) {
      final st = filteredStudents[i];
      final h = halaqat.where((x) => x.id == st.halaqaId).firstOrNull;
      rankedEntries.add(
        RankedStudentEntry(
          rank: i + 1,
          student: st,
          halaqaName: h?.name,
          score: st.totalPoints,
        ),
      );
    }

    String? competitionTitle;
    if (_posterFilterScope == 'specific_competition' && _posterCompetitionId != null) {
      final comp = competitions.where((c) => c.id == _posterCompetitionId).firstOrNull;
      competitionTitle = comp?.title;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controls Column
            Expanded(
              flex: isWide ? 5 : 0,
              child: _buildPosterControls(
                students: students,
                halaqat: halaqat,
                competitions: competitions,
                isDark: isDark,
              ),
            ),
            if (isWide) const SizedBox(width: 20) else const SizedBox(height: 24),

            // Live Preview Column
            Expanded(
              flex: isWide ? 6 : 0,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF191218) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'معاينة البوستر المخصص للنشر',
                              style: AppTypography.font(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _posterConfig.aspectRatio == PosterAspectRatio.square1x1
                                    ? '1:1 مربع (منشور فيسبوك)'
                                    : '9:16 طولي (ستوري/واتساب)',
                                style: AppTypography.font(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.goldDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: RepaintBoundary(
                            key: _posterBoundaryKey,
                            child: HonorPosterRenderView(
                              mosqueName: widget.mosque.name,
                              students: rankedEntries,
                              config: _posterConfig,
                              competitionTitle: competitionTitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('نشر ومشاركة البوستر (WhatsApp / فيسبوك)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.goldDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            DesignExportService.shareDesign(
                              context: context,
                              boundaryKey: _posterBoundaryKey,
                              fileNamePrefix: 'honor_poster_${DateTime.now().millisecondsSinceEpoch}',
                              shareMessage: '''
🌟 ${_posterConfig.title} 🌟
${widget.mosque.name} - وزارة التربية والتعليم

«مبارك لطلابنا المتفوقين في حلقات القرآن الكريم هذا الإنجاز المبارك» 🌿
''',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      IconButton.filledTonal(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'حفظ البوستر كصورة عالية الدقة',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          DesignExportService.saveToDevice(
                            context: context,
                            boundaryKey: _posterBoundaryKey,
                            fileNamePrefix: 'honor_poster',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPosterControls({
    required List<Student> students,
    required List<Halaqa> halaqat,
    required List<Competition> competitions,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231822) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Scope
          Text(
            'نطاق وفلاتر التكريم',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _posterFilterScope,
            decoration: _inputDecoration('المصدر / النطاق', isDark),
            items: const [
              DropdownMenuItem(value: 'all_mosque', child: Text('جميع طلاب المسجد')),
              DropdownMenuItem(value: 'specific_halaqa', child: Text('حلقة قرآنية محددة')),
              DropdownMenuItem(value: 'specific_competition', child: Text('مسابقة معتمدة محددة')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _posterFilterScope = val);
            },
          ),
          const SizedBox(height: 12),

          if (_posterFilterScope == 'specific_halaqa') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _posterHalaqaId,
              decoration: _inputDecoration('اختر الحلقة', isDark),
              items: halaqat.map((h) {
                return DropdownMenuItem(value: h.id, child: Text(h.name));
              }).toList(),
              onChanged: (val) => setState(() => _posterHalaqaId = val),
            ),
            const SizedBox(height: 12),
          ],

          if (_posterFilterScope == 'specific_competition') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _posterCompetitionId,
              decoration: _inputDecoration('اختر المسابقة', isDark),
              items: competitions.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.title));
              }).toList(),
              onChanged: (val) => setState(() => _posterCompetitionId = val),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 24),

          // Layout Style & Student Cap
          Text(
            'شكل التصميم والحد الأقصى للطلاب',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<PosterLayoutType>(
            initialValue: _posterConfig.layoutType,
            decoration: _inputDecoration('نمط العرض وسقف العدد', isDark),
            items: const [
              DropdownMenuItem(
                value: PosterLayoutType.podiumTop3,
                child: Text('منصة التتويج الملكية (أفضل 3 طلاب)'),
              ),
              DropdownMenuItem(
                value: PosterLayoutType.honorListTop5,
                child: Text('لوحة الشرف الذهبية (الـ 5 الأوائل)'),
              ),
              DropdownMenuItem(
                value: PosterLayoutType.honorListTop10,
                child: Text('لوحة الشرف الوزارية (الـ 10 الأوائل)'),
              ),
              DropdownMenuItem(
                value: PosterLayoutType.singleSpotlight,
                child: Text('وسام تكريم فردي (طالب الأسبوع / متميز)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _posterConfig = _posterConfig.copyWith(layoutType: val));
              }
            },
          ),
          const SizedBox(height: 12),

          if (_posterConfig.layoutType == PosterLayoutType.singleSpotlight) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _spotlightStudentId,
              decoration: _inputDecoration('اختر الطالب للتكريم الفردي', isDark),
              items: students.map((s) {
                return DropdownMenuItem(value: s.id, child: Text(s.fullName));
              }).toList(),
              onChanged: (val) => setState(() => _spotlightStudentId = val),
            ),
            const SizedBox(height: 12),
          ],

          // Aspect Ratio
          Text(
            'مقاس النشر الاجتماعي',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('1:1 منشور مربع')),
                  selected: _posterConfig.aspectRatio == PosterAspectRatio.square1x1,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _posterConfig = _posterConfig.copyWith(aspectRatio: PosterAspectRatio.square1x1);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('9:16 ستوري / واتساب')),
                  selected: _posterConfig.aspectRatio == PosterAspectRatio.story9x16,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _posterConfig = _posterConfig.copyWith(aspectRatio: PosterAspectRatio.story9x16);
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Theme Variant
          Text(
            'القالب والنمط اللوني',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildThemeChip(
                label: 'ذهبي ملكي',
                isSelected: _posterConfig.themeVariant == PosterThemeVariant.ministerialGold,
                color: AppColors.gold,
                onTap: () => setState(() {
                  _posterConfig = _posterConfig.copyWith(themeVariant: PosterThemeVariant.ministerialGold);
                }),
              ),
              const SizedBox(width: 6),
              _buildThemeChip(
                label: 'زمردي قرآني',
                isSelected: _posterConfig.themeVariant == PosterThemeVariant.quranicEmerald,
                color: AppColors.emeraldPrimary,
                onTap: () => setState(() {
                  _posterConfig = _posterConfig.copyWith(themeVariant: PosterThemeVariant.quranicEmerald);
                }),
              ),
              const SizedBox(width: 6),
              _buildThemeChip(
                label: 'أوبسيديان داكن',
                isSelected: _posterConfig.themeVariant == PosterThemeVariant.executiveDark,
                color: const Color(0xFF231822),
                onTap: () => setState(() {
                  _posterConfig = _posterConfig.copyWith(themeVariant: PosterThemeVariant.executiveDark);
                }),
              ),
            ],
          ),

          const Divider(height: 24),

          // Custom Titles
          Text(
            'نصوص وعناوين البوستر',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _posterMinistryHeaderController,
            decoration: _inputDecoration('الترويسة الوزارية / المؤسسية (أعلى البوستر)', isDark),
            onChanged: (val) => setState(() => _posterConfig = _posterConfig.copyWith(ministryHeader: val)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            decoration: _inputDecoration('عنوان لوحة الشرف الرئيسي', isDark),
            onChanged: (val) => setState(() => _posterConfig = _posterConfig.copyWith(title: val)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subtitleController,
            decoration: _inputDecoration('الوصف أو العبارة التكريمية', isDark),
            onChanged: (val) => setState(() => _posterConfig = _posterConfig.copyWith(subtitle: val)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _posterStampTextController,
            decoration: _inputDecoration('نص ختم الاعتماد الرسمي (أسفل البوستر)', isDark),
            onChanged: (val) => setState(() => _posterConfig = _posterConfig.copyWith(stampText: val)),
          ),

          const Divider(height: 24),

          // Toggles
          Text(
            'خيارات إضافية',
            style: AppTypography.font(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildSwitchTile('إظهار الترويسة الوزارية الرسمية', _posterConfig.showMinistryHeader, (v) {
            setState(() => _posterConfig = _posterConfig.copyWith(showMinistryHeader: v));
          }),
          _buildSwitchTile('إظهار ختم الاعتماد الرسمي', _posterConfig.showMosqueStamp, (v) {
            setState(() => _posterConfig = _posterConfig.copyWith(showMosqueStamp: v));
          }),
          _buildSwitchTile('إظهار مجموع النقاط والأوسمة', _posterConfig.showPoints, (v) {
            setState(() => _posterConfig = _posterConfig.copyWith(showPoints: v));
          }),
          _buildSwitchTile('إظهار صورة الطالب الشخصية', _posterConfig.showStudentAvatar, (v) {
            setState(() => _posterConfig = _posterConfig.copyWith(showStudentAvatar: v));
          }),
          _buildSwitchTile('إظهار اسم الحلقة القرآنية', _posterConfig.showHalaqaName, (v) {
            setState(() => _posterConfig = _posterConfig.copyWith(showHalaqaName: v));
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // Common UI Helpers
  // =========================================================================

  Widget _buildThemeChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isSelected ? 0.25 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.font(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: AppTypography.font(fontSize: 12.5)),
      value: value,
      activeTrackColor: AppColors.goldDark,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.font(fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
    );
  }
}
