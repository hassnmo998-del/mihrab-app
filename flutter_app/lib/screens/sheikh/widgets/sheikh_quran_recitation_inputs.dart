import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/quran_data.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';
import '../../../theme/app_theme.dart';
import '../dialogs/multi_surah_selector_dialog.dart';

class SheikhQuranRecitationInputs extends StatefulWidget {
  final Student? selectedStudent;
  final Sheikh sheikh;
  final String? selectedCourseId;
  final VoidCallback onRecitationSaved;

  const SheikhQuranRecitationInputs({
    super.key,
    required this.selectedStudent,
    required this.sheikh,
    required this.selectedCourseId,
    required this.onRecitationSaved,
  });

  @override
  State<SheikhQuranRecitationInputs> createState() => _SheikhQuranRecitationInputsState();
}

class _SheikhQuranRecitationInputsState extends State<SheikhQuranRecitationInputs> {
  String _recitationMode = 'surah_passage';
  final Set<String> _selectedSurahs = {'النبأ'};
  String _singleSurah = 'النبأ';
  final TextEditingController _fromAyahCtrl = TextEditingController(text: '1');
  final TextEditingController _toAyahCtrl = TextEditingController(text: '40');
  final Set<int> _selectedAjza = {30};
  final TextEditingController _memPointsCtrl = TextEditingController(text: '20');
  final TextEditingController _memNotesCtrl = TextEditingController();
  String _sessionType = 'new_memorization';
  bool _memCountsTowardsStatistics = true;

  @override
  void dispose() {
    _fromAyahCtrl.dispose();
    _toAyahCtrl.dispose();
    _memPointsCtrl.dispose();
    _memNotesCtrl.dispose();
    super.dispose();
  }

  void _calculateDefaultPoints() {
    int base = 20;
    if (_sessionType == 'new_memorization') {
      base = 20;
    } else if (_sessionType == 'review') {
      base = 15;
    } else {
      base = 40;
    }
    _memPointsCtrl.text = base.toString();
  }

  void _handleSave(BuildContext context, DataService data) {
    if (widget.selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الطالب أولاً')),
      );
      return;
    }

    final points = int.tryParse(_memPointsCtrl.text.trim()) ?? 20;
    final student = widget.selectedStudent!;
    final items = <Map<String, dynamic>>[];

    if (_recitationMode == 'surah_passage') {
      final s = getSurahByName(_singleSurah);
      final maxAyahs = s?.ayahCount ?? 286;
      final fromAyah = (int.tryParse(_fromAyahCtrl.text) ?? 1).clamp(1, maxAyahs);
      final toAyah = (int.tryParse(_toAyahCtrl.text) ?? maxAyahs).clamp(fromAyah, maxAyahs);
      final juz = getJuzForSurahAndAyah(s?.number ?? 1, fromAyah);
      items.add({
        'surahName': s?.name ?? _singleSurah,
        'fromAyah': fromAyah,
        'toAyah': toAyah,
        'juzNumber': juz,
      });
    } else if (_recitationMode == 'multi_surah') {
      if (_selectedSurahs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار سورة واحدة على الأقل')),
        );
        return;
      }
      for (final surah in _selectedSurahs) {
        final s = getSurahByName(surah);
        if (s != null) {
          items.add({
            'surahName': s.name,
            'fromAyah': 1,
            'toAyah': s.ayahCount,
            'juzNumber': s.startJuz,
          });
        }
      }
    } else if (_recitationMode == 'multi_juz') {
      if (_selectedAjza.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار جزء واحد على الأقل')),
        );
        return;
      }
      for (final juz in _selectedAjza) {
        final boundaries = quranJuzBoundaries.where((b) => b.juzNumber == juz);
        for (final b in boundaries) {
          final s = getSurahByNumber(b.surahNumber);
          if (s != null) {
            items.add({
              'surahName': s.name,
              'fromAyah': b.fromAyah,
              'toAyah': b.toAyah,
              'juzNumber': juz,
            });
          }
        }
      }
    }

    data.recordRecitationBatch(
      studentId: student.id,
      halaqaId: student.halaqaId,
      sheikhId: widget.sheikh.id,
      courseId: widget.selectedCourseId,
      items: items,
      sessionType: _sessionType,
      points: points,
      notes: _memNotesCtrl.text.trim(),
      countsTowardsStatistics: _memCountsTowardsStatistics,
    );

    _memNotesCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_memCountsTowardsStatistics
            ? 'تم تسجيل التسميع (${items.length} مقطع) ورصد +$points نقطة للطالب بنجاح! 🎉'
            : 'تم حفظ التسميع في السجل كجلسة خاصة (غير محسوبة بالإحصائيات العامة).'),
        backgroundColor: AppTheme.emeraldPrimary,
      ),
    );

    widget.onRecitationSaved();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<DataService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نمط التسميع المطلوب *',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, segConstraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: segConstraints.maxWidth),
                child: SegmentedButton<String>(
                  style: const ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
                  segments: const [
                    ButtonSegment(
                      value: 'surah_passage',
                      label: Text('مقطع من سورة'),
                      icon: Icon(Icons.short_text_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'multi_surah',
                      label: Text('سور كاملة'),
                      icon: Icon(Icons.library_books_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 'multi_juz',
                      label: Text('أجزاء كاملة'),
                      icon: Icon(Icons.bookmark_added_rounded, size: 16),
                    ),
                  ],
                  selected: {_recitationMode},
                  onSelectionChanged: (set) => setState(() => _recitationMode = set.first),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Mode 1: Surah Passage (Ministerial Custom Inputs)
        if (_recitationMode == 'surah_passage') ...[
          MinisterialDropdownField<String>(
            label: 'السورة الكريمة',
            isRequired: true,
            value: _singleSurah,
            prefixIcon: Icon(Icons.auto_stories, color: AppColors.terracottaPrimary, size: 20),
            items: quranSurahsInfo.map((s) => DropdownMenuItem(
              value: s.name,
              child: Text('${s.number}. سورة ${s.name} (${s.ayahCount} آية)'),
            )).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _singleSurah = val;
                  final s = getSurahByName(val);
                  if (s != null) {
                    _fromAyahCtrl.text = '1';
                    _toAyahCtrl.text = s.ayahCount.toString();
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final fromField = MinisterialTextField(
                label: 'من آية',
                isRequired: true,
                controller: _fromAyahCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icon(Icons.format_list_numbered, color: AppColors.terracottaPrimary, size: 18),
                helperText: 'بداية المقطع',
              );
              final toField = MinisterialTextField(
                label: 'إلى آية',
                isRequired: true,
                controller: _toAyahCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icon(Icons.format_list_numbered_rtl, color: AppColors.terracottaPrimary, size: 18),
                helperText: 'نهاية المقطع (سورة $_singleSurah)',
              );

              if (isNarrow) {
                return Column(
                  children: [
                    fromField,
                    const SizedBox(height: 12),
                    toField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: fromField),
                  const SizedBox(width: 12),
                  Expanded(child: toField),
                ],
              );
            },
          ),
        ],

        // Mode 2: Multi-Surahs
        if (_recitationMode == 'multi_surah') ...[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidianEspresso,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => showMultiSurahSelectorDialog(
                  context,
                  _selectedSurahs,
                  () => setState(() {}),
                ),
                icon: const Icon(Icons.add_task),
                label: const Text('اختيار وتحديد السور'),
              ),
              Text(
                'تم اختيار ${_selectedSurahs.length} سورة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedSurahs.isEmpty)
            Text(
              'يرجى تحديد سورة واحدة على الأقل بالضغط على زر الاختيار أعلاه.',
              style: GoogleFonts.cairo(color: Colors.red, fontSize: 12),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInputFill : AppColors.lightInputFill,
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _selectedSurahs.map((surah) {
                  final sInfo = getSurahByName(surah);
                  return Chip(
                    shape: const StadiumBorder(),
                    label: Text('$surah (${sInfo?.ayahCount ?? 0} آية)'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _selectedSurahs.remove(surah)),
                  );
                }).toList(),
              ),
            ),
        ],

        // Mode 3: Multi-Ajza
        if (_recitationMode == 'multi_juz') ...[
          Row(
            children: [
              Text('اختر الأجزاء الكريمة كاملة:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                'تم تحديد ${_selectedAjza.length} جزء',
                style: GoogleFonts.cairo(color: AppColors.terracottaPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInputFill : AppColors.lightInputFill,
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.lightBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(30, (i) => i + 1).map((juz) {
                  final isSel = _selectedAjza.contains(juz);
                  return FilterChip(
                    shape: const StadiumBorder(),
                    selected: isSel,
                    label: Text('جزء $juz'),
                    selectedColor: AppColors.terracottaPrimary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.terracottaPrimary,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAjza.add(juz);
                        } else {
                          _selectedAjza.remove(juz);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Session Type (Ministerial Dropdown)
        MinisterialDropdownField<String>(
          label: 'نوع الجلسة',
          isRequired: true,
          value: _sessionType,
          items: const [
            DropdownMenuItem(value: 'new_memorization', child: Text('حفظ جديد')),
            DropdownMenuItem(value: 'review', child: Text('مراجعة وتثبيت')),
            DropdownMenuItem(value: 'test', child: Text('اختبار جزء معتمد')),
          ],
          onChanged: (v) => setState(() {
            _sessionType = v ?? 'new_memorization';
            _calculateDefaultPoints();
          }),
        ),
        const SizedBox(height: 14),

        // Numerical Points Input (Ministerial Text Field)
        MinisterialTextField(
          label: 'النقاط المستحقة للطالب',
          isRequired: true,
          controller: _memPointsCtrl,
          keyboardType: TextInputType.number,
          prefixIcon: Icon(Icons.stars, color: AppColors.gold, size: 20),
          helperText: 'نقاط رقمية حرة يحددها الشيخ تقديراً لجهد الطالب وإتقانه',
        ),
        const SizedBox(height: 14),

        // Notes (Ministerial Text Field)
        MinisterialTextField(
          label: 'ملاحظات وتوجيهات الشيخ للطالب',
          controller: _memNotesCtrl,
          hintText: 'مثال: إتقان أحكام الغنن والمد المتصل',
          prefixIcon: Icon(Icons.edit_note, color: AppColors.terracottaPrimary, size: 20),
        ),
        const SizedBox(height: 14),

        // Toggle: Count towards general statistics & leaderboard
        Container(
          decoration: BoxDecoration(
            color: _memCountsTowardsStatistics
                ? AppColors.terracottaPrimary.withValues(alpha: 0.08)
                : Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _memCountsTowardsStatistics
                  ? AppColors.terracottaPrimary.withValues(alpha: 0.3)
                  : Colors.amber.shade400,
            ),
          ),
          child: SwitchListTile(
            value: _memCountsTowardsStatistics,
            onChanged: (val) => setState(() => _memCountsTowardsStatistics = val),
            title: Text(
              'احتساب هذا التسميع ضمن الإحصائيات العامة للطالب',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              _memCountsTowardsStatistics
                  ? 'مفعّل: يُحسب في خطة ختمة المصحف والنقاط والترتيب العام'
                  : 'معطّل: يُحفظ في سجل الطالب فقط ولا يدخل في إحصائيات الختمة أو الترتيب العام',
              style: GoogleFonts.cairo(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            activeThumbColor: AppColors.terracottaPrimary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          ),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _handleSave(context, data),
            icon: const Icon(Icons.save),
            label: Text('حفظ تسميع القرآن ورصد النقاط', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidianEspresso,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
