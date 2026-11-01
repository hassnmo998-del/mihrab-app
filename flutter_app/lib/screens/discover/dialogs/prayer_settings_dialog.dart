import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/prayer_calculation_settings.dart';
import '../../../presentation/widgets/unified_badge.dart';
import '../../../services/adhan_service.dart';

/// Modal dialog allowing the user to configure prayer location (GPS or manual city),
/// astronomical calculation method, Asr madhab, and minute-by-minute offsets.
class PrayerSettingsDialog extends StatefulWidget {
  final bool isDark;

  const PrayerSettingsDialog({super.key, required this.isDark});

  static Future<void> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrayerSettingsDialog(isDark: isDark),
    );
  }

  @override
  State<PrayerSettingsDialog> createState() => _PrayerSettingsDialogState();
}

class _PrayerSettingsDialogState extends State<PrayerSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  bool _isLocatingGps = false;

  bool get isDark => widget.isDark;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGpsClick() async {
    setState(() => _isLocatingGps = true);
    try {
      final success = await AdhanService.instance.setLocationToGps();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 تم تحديد موقعك الحالي (${AdhanService.instance.cityName}) وتحديث المواقيت بنجاح',
            ),
            backgroundColor: Theme.of(context).primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ تعذر جلب الموقع عبر GPS: يرجى التحقق من تشغيل خدمة الموقع ومنح الإذن للتطبيق',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  List<PrayerCity> _getFilteredCities() {
    List<PrayerCity> list;
    switch (_selectedCategory) {
      case 'سوريا':
        list = PrayerCitiesData.syrianCities;
        break;
      case 'السعودية والخليج':
        list = PrayerCitiesData.saudiAndGulfCities;
        break;
      case 'مصر وبلاد الشام':
        list = PrayerCitiesData.levantAndEgyptCities;
        break;
      case 'العراق واليمن':
        list = PrayerCitiesData.iraqAndYemenCities;
        break;
      case 'تركيا':
        list = PrayerCitiesData.turkeyCities;
        break;
      case 'عالمياً':
        list = PrayerCitiesData.worldwideCities;
        break;
      default:
        list = PrayerCitiesData.allCities;
        break;
    }

    if (_searchQuery.isEmpty) return list;

    return list.where((c) {
      final matchName = c.nameAr.toLowerCase().contains(_searchQuery);
      final matchCountry = c.countryAr.toLowerCase().contains(_searchQuery);
      return matchName || matchCountry;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final service = AdhanService.instance;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات المواقيت والموقع الجغرافي',
                        style: AppTypography.titleBold(context, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<String>(
                        valueListenable: service.cityNameNotifier,
                        builder: (context, cityName, _) {
                          return Text(
                            'الموقع الحالي: $cityName',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : AppColors.obsidianEspresso,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightInputFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabCtrl,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.location_on_rounded, size: 18),
                  text: 'المدينة والموقع',
                ),
                Tab(
                  icon: Icon(Icons.calculate_outlined, size: 18),
                  text: 'طريقة الحساب',
                ),
                Tab(
                  icon: Icon(Icons.more_time_rounded, size: 18),
                  text: 'تعديل الدقائق',
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildLocationTab(context),
                _buildCalculationTab(context),
                _buildAdjustmentsTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: LOCATION & CITY SELECTION
  // -------------------------------------------------------------
  Widget _buildLocationTab(BuildContext context) {
    final service = AdhanService.instance;
    final filteredCities = _getFilteredCities();

    return Column(
      children: [
        // One-Click GPS Button (Prominent)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isLocatingGps ? null : _handleGpsClick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: _isLocatingGps
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLocatingGps
                                  ? 'جارٍ تحديد الموقع عبر الأقمار الصناعية GPS...'
                                  : 'تحديد موقعي الحالي تلقائياً (GPS)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'يلتقط إحداثياتك الحالية بدقة ويضبط أوقات الأذان فوراً',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ابحث عن مدينتك (مثل: حلب، حمص، الرياض، إسطنبول...)...',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightInputFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
          ),
        ),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children:
                [
                  'الكل',
                  'سوريا',
                  'السعودية والخليج',
                  'مصر وبلاد الشام',
                  'العراق واليمن',
                  'تركيا',
                  'عالمياً',
                ].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(cat),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      selected: isSelected,
                      selectedColor: Theme.of(context).primaryColor,
                      backgroundColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightInputFill,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
          ),
        ),

        const Divider(height: 1),

        // Cities List
        Expanded(
          child: filteredCities.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد مدينة مطابقة للبحث',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : AppColors.obsidianEspresso,
                    ),
                  ),
                )
              : ValueListenableBuilder<String>(
                  valueListenable: service.cityNameNotifier,
                  builder: (context, currentCityName, _) {
                    return ListView.builder(
                      itemCount: filteredCities.length,
                      itemBuilder: (context, idx) {
                        final city = filteredCities[idx];
                        final isSelected =
                            !service.isGpsLocation &&
                            (currentCityName == city.displayName ||
                                currentCityName == city.nameAr);

                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.15)
                                  : (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightInputFill),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_city_rounded,
                              size: 18,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                          title: Text(
                            city.nameAr,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          subtitle: Text(
                            city.countryAr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.obsidianEspresso,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                )
                              : null,
                          onTap: () async {
                            await service.setCity(city);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم اختيار ${city.displayName} وحساب المواقيت 🕌',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 2: CALCULATION METHOD & ASR MADHAB
  // -------------------------------------------------------------
  Widget _buildCalculationTab(BuildContext context) {
    final service = AdhanService.instance;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Section: Asr Madhab
        Text(
          'مذهب صلاة العصر',
          style: AppTypography.titleBold(context, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'يحدد وقت بداية أذان العصر بحسب طول ظل الشيء:',
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? Colors.white60 : AppColors.obsidianEspresso,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Madhab>(
          valueListenable: service.madhabNotifier,
          builder: (context, activeMadhab, _) {
            return Column(
              children: MadhabInfo.all.map((info) {
                final isSelected = activeMadhab == info.madhab;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightInputFill),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      info.titleAr,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      info.descriptionAr,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () => service.setMadhab(info.madhab),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),

        // Section: Calculation Methods
        Text(
          'طريقة الحساب الفلكي للمواقيت',
          style: AppTypography.titleBold(context, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'تعتمد كل دولة أو جهة إسلامية زوايا محددة لحساب الفجر والعشاء ودقائق الأمان:',
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? Colors.white60 : AppColors.obsidianEspresso,
          ),
        ),
        const SizedBox(height: 8),

        ValueListenableBuilder<CalculationMethod>(
          valueListenable: service.calculationMethodNotifier,
          builder: (context, activeMethod, _) {
            return Column(
              children: CalculationMethodInfo.all.map((info) {
                final isSelected = activeMethod == info.method;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightInputFill),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.titleAr,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                        ),
                        UnifiedBadge(
                          label: info.regionAr,
                          backgroundColor: isSelected
                              ? Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.15)
                              : (isDark ? Colors.white10 : Colors.black12),
                          textColor: isSelected
                              ? Theme.of(context).primaryColor
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        info.descriptionAr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white60
                              : AppColors.obsidianEspresso,
                        ),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () => service.setCalculationMethod(info.method),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: MINUTE-BY-MINUTE ADJUSTMENTS
  // -------------------------------------------------------------
  Widget _buildAdjustmentsTab(BuildContext context) {
    final service = AdhanService.instance;
    final prayers = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: service.manualAdjustmentsNotifier,
      builder: (context, adjustments, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'إذا لاحظت أي فارق دقيقة أو دقيقتين عن أذان المسجد المجاور لك، يمكنك تقديم أو تأخير أي صلاة بالدقائق لمطابقتها تماماً:',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            ...prayers.map((prayer) {
              final offset = adjustments[prayer] ?? 0;
              final isModified = offset != 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightInputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isModified
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                        : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      prayer,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isModified
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        offset == 0
                            ? 'بدون تعديل (0)'
                            : (offset > 0 ? '+$offset دقيقة' : '$offset دقيقة'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isModified
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isModified
                              ? Theme.of(context).primaryColor
                              : (isDark
                                    ? Colors.white60
                                    : AppColors.obsidianEspresso),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Minus button
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      iconSize: 22,
                      color: isDark ? Colors.white70 : Colors.black87,
                      onPressed: () {
                        service.setPrayerAdjustment(prayer, offset - 1);
                      },
                    ),
                    // Plus button
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      iconSize: 22,
                      color: Theme.of(context).primaryColor,
                      onPressed: () {
                        service.setPrayerAdjustment(prayer, offset + 1);
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await service.resetAdjustments();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تمت إعادة ضبط جميع دقائق الصلوات إلى الصفر',
                      ),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('إعادة ضبط جميع الدقائق إلى الصفر'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
