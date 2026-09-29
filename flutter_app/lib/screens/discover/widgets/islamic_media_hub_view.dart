import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── API ──────────────────────────────────────────────────────────────────────
const _kApiKey = 'AIzaSyD_NLXfElTS2dZmEc26N0zvuiAIpNxUYFA';
const _kCacheKey = 'islamic_media_v3';
const _kCacheTsKey = 'islamic_media_v3_ts';
const _kCacheHours = 6;

// ─── القنوات الموثوقة ─────────────────────────────────────────────────────────
class _Channel {
  final String id;
  final String name;
  final String tag; // للتصنيف
  const _Channel(this.id, this.name, this.tag);
}

const _channels = [
  _Channel('UCmGajGY-qEkBVFPVm7bSMRQ', 'النابلسي', 'علماء'),
  _Channel('UCmkzYfXC9VU2u6bJD2m-o5Q', 'محمد خير الشعال', 'علماء'),
  _Channel('UCdHi4h_BMr4M3KDCP7BWKYA', 'عبد الفتاح أنيس', 'علماء'),
  _Channel('UCaEpT0N-ue4FMXsSV5b3P2g', 'مشاري العفاسي', 'قرآن'),
  _Channel('UCHcEWHl0m8DFk3-S0akdVqQ', 'قناة القرآن', 'قرآن'),
  _Channel('UCz2FDE3K8wCJNMbp3S8bz4Q', 'سعد الغامدي', 'قرآن'),
  _Channel('UCy37KFmPQPapjuXcMGHbyYw', 'دريوس', 'أناشيد'),
  _Channel('UCb9DFGxLBGNh4wN1E5bCWrA', 'أناشيد إسلامية', 'أناشيد'),
  _Channel('UClZp2fFMNiE-EjWuHDhF7fA', 'بيّنات', 'دروس'),
];

const _tags = ['الكل', 'قرآن', 'علماء', 'دروس', 'أناشيد'];

// ─── موديل الفيديو ────────────────────────────────────────────────────────────
class _Video {
  final String id;
  final String title;
  final String channel;
  final String channelId;
  final String thumb;
  final String published;
  final String tag;

  const _Video({
    required this.id,
    required this.title,
    required this.channel,
    required this.channelId,
    required this.thumb,
    required this.published,
    required this.tag,
  });

  String get url => 'https://www.youtube.com/watch?v=$id';

  factory _Video.fromApi(Map<String, dynamic> j, String tag) {
    final s = j['snippet'] as Map<String, dynamic>? ?? {};
    final vid = j['id'] is Map ? (j['id'] as Map)['videoId'] as String? ?? '' : j['id'] as String? ?? '';
    final t = s['thumbnails'] as Map<String, dynamic>? ?? {};
    final th = (t['high'] ?? t['medium'] ?? t['default']) as Map<String, dynamic>? ?? {};
    return _Video(
      id: vid,
      title: s['title'] as String? ?? '',
      channel: s['channelTitle'] as String? ?? '',
      channelId: s['channelId'] as String? ?? '',
      thumb: th['url'] as String? ?? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
      published: s['publishedAt'] as String? ?? '',
      tag: tag,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'channel': channel,
        'channelId': channelId, 'thumb': thumb,
        'published': published, 'tag': tag,
      };

  factory _Video.fromJson(Map<String, dynamic> j) => _Video(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        channel: j['channel'] as String? ?? '',
        channelId: j['channelId'] as String? ?? '',
        thumb: j['thumb'] as String? ?? '',
        published: j['published'] as String? ?? '',
        tag: j['tag'] as String? ?? '',
      );
}

// ─── خدمة البيانات ────────────────────────────────────────────────────────────
class _Api {
  static Future<List<_Video>> fetchAll() async {
    final futures = _channels.map((ch) => _fetchChannel(ch)).toList();
    final lists = await Future.wait(futures);
    final all = lists.expand((l) => l).toList()
      ..sort((a, b) => b.published.compareTo(a.published));
    return all;
  }

  static Future<List<_Video>> _fetchChannel(_Channel ch) async {
    try {
      final uri = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search'
        '?key=$_kApiKey&channelId=${ch.id}&part=snippet'
        '&order=date&type=video&maxResults=10&relevanceLanguage=ar',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (body['items'] as List<dynamic>? ?? [])
          .map((e) => _Video.fromApi(e as Map<String, dynamic>, ch.tag))
          .where((v) => v.id.isNotEmpty && v.title.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<_Video>> search(String q) async {
    if (q.trim().isEmpty) return [];
    try {
      final trusted = _channels.map((c) => c.id).toSet();
      final uri = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search'
        '?key=$_kApiKey&q=${Uri.encodeComponent(q)}&part=snippet'
        '&type=video&maxResults=30&relevanceLanguage=ar',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['items'] as List<dynamic>? ?? [])
          .map((e) => _Video.fromApi(e as Map<String, dynamic>, 'بحث'))
          .where((v) => v.id.isNotEmpty && v.title.isNotEmpty)
          .toList();
      // نفضّل القنوات الموثوقة ثم نضيف الباقي
      final pref = items.where((v) => trusted.contains(v.channelId)).toList();
      final rest = items.where((v) => !trusted.contains(v.channelId)).toList();
      return [...pref, ...rest];
    } catch (_) {
      return [];
    }
  }

  static Future<List<_Video>> loadCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ts = p.getInt(_kCacheTsKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _kCacheHours * 3600000) return [];
      final raw = p.getString(_kCacheKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => _Video.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> saveCache(List<_Video> v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kCacheKey, jsonEncode(v.map((e) => e.toJson()).toList()));
      await p.setInt(_kCacheTsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}

// ─── الشاشة الرئيسية ──────────────────────────────────────────────────────────
class IslamicMediaHubView extends StatefulWidget {
  final bool isDark;
  const IslamicMediaHubView({super.key, required this.isDark});

  @override
  State<IslamicMediaHubView> createState() => _IslamicMediaHubViewState();
}

class _IslamicMediaHubViewState extends State<IslamicMediaHubView> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<_Video> _all = [];
  List<_Video> _search = [];
  bool _loading = true;
  bool _searching = false;
  bool _searchMode = false;
  String _tag = 'الكل';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await _Api.loadCache();
    if (cached.isNotEmpty) {
      if (mounted) setState(() { _all = cached; _loading = false; });
      _Api.fetchAll().then((fresh) {
        if (fresh.isNotEmpty) {
          _Api.saveCache(fresh);
          if (mounted) setState(() => _all = fresh);
        }
      });
    } else {
      final fresh = await _Api.fetchAll();
      await _Api.saveCache(fresh);
      if (mounted) setState(() { _all = fresh; _loading = false; });
    }
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) {
      if (mounted) setState(() { _searchMode = false; _search = []; });
      return;
    }
    if (mounted) setState(() { _searchMode = true; _searching = true; });
    final r = await _Api.search(q);
    if (mounted) setState(() { _search = r; _searching = false; });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _focusNode.unfocus();
    setState(() { _searchMode = false; _search = []; });
  }

  List<_Video> get _shown {
    if (_searchMode) return _search;
    if (_tag == 'الكل') return _all;
    return _all.where((v) => v.tag == _tag).toList();
  }

  String _ago(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays < 1) return 'اليوم';
      if (diff.inDays < 7) return 'منذ ${diff.inDays}د';
      if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()}أ';
      if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()}ش';
      return 'منذ ${(diff.inDays / 365).floor()}سنة';
    } catch (_) { return ''; }
  }

  Future<void> _open(_Video v) async {
    final uri = Uri.parse(v.url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openChannel(String id) async {
    final uri = Uri.parse('https://www.youtube.com/channel/$id');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool get _isWide => MediaQuery.sizeOf(context).width > 700;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final surface = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSec = isDark ? Colors.white60 : Colors.black45;
    final chipBg = isDark ? const Color(0xFF272727) : const Color(0xFFE5E5E5);
    final chipActiveBg = isDark ? Colors.white : Colors.black87;
    final chipActiveText = isDark ? Colors.black : Colors.white;

    return Container(
      color: bg,
      child: Column(
        children: [
          // ── شريط البحث ──────────────────────────────────────────────────────
          Container(
            color: bg,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      textDirection: TextDirection.rtl,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن دروس، قرآن، أناشيد...',
                        hintStyle: TextStyle(fontSize: 13, color: textSec),
                        hintTextDirection: TextDirection.rtl,
                        isDense: true,
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, size: 20, color: textSec),
                        suffixIcon: _searchMode
                            ? GestureDetector(
                                onTap: _clearSearch,
                                child: Icon(Icons.close, size: 18, color: textSec),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: _doSearch,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    setState(() => _loading = true);
                    await _Api.fetchAll().then((v) async {
                      await _Api.saveCache(v);
                      if (mounted) setState(() { _all = v; _loading = false; });
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Icon(Icons.refresh_rounded, size: 18, color: textSec),
                  ),
                ),
              ],
            ),
          ),

          // ── شرائح التصنيف (تختفي في وضع البحث) ───────────────────────────
          if (!_searchMode)
            Container(
              color: bg,
              height: 40,
              padding: const EdgeInsets.only(bottom: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _tags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final t = _tags[i];
                  final active = _tag == t;
                  return GestureDetector(
                    onTap: () => setState(() => _tag = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? chipActiveBg : chipBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: active ? chipActiveText : textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── المحتوى ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _searchMode && _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _shown.isEmpty
                        ? _buildEmpty(textSec)
                        : _isWide
                            ? _buildGrid(textPrimary, textSec, isDark)
                            : _buildList(textPrimary, textSec, isDark),
          ),
        ],
      ),
    );
  }

  // ── قائمة عمودية (موبايل / آيفون) ────────────────────────────────────────
  Widget _buildList(Color textPrimary, Color textSec, bool isDark) {
    final videos = _shown;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: videos.length,
      itemBuilder: (_, i) => _VideoTile(
        video: videos[i],
        ago: _ago(videos[i].published),
        textPrimary: textPrimary,
        textSec: textSec,
        isDark: isDark,
        onTap: () => _open(videos[i]),
        onChannelTap: () => _openChannel(videos[i].channelId),
      ),
    );
  }

  // ── شبكة (ويندوز / تابلت) ────────────────────────────────────────────────
  Widget _buildGrid(Color textPrimary, Color textSec, bool isDark) {
    final videos = _shown;
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 1100 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: videos.length,
      itemBuilder: (_, i) => _VideoGridCard(
        video: videos[i],
        ago: _ago(videos[i].published),
        textPrimary: textPrimary,
        textSec: textSec,
        isDark: isDark,
        onTap: () => _open(videos[i]),
        onChannelTap: () => _openChannel(videos[i].channelId),
      ),
    );
  }

  Widget _buildEmpty(Color textSec) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 60, color: textSec),
            const SizedBox(height: 12),
            Text(
              _searchMode ? 'لا نتائج لهذا البحث' : 'لا يوجد محتوى',
              style: TextStyle(color: textSec, fontSize: 15),
            ),
          ],
        ),
      );
}

// ─── بطاقة فيديو (قائمة عمودية — أسلوب يوتيوب موبايل) ────────────────────────
class _VideoTile extends StatelessWidget {
  final _Video video;
  final String ago;
  final Color textPrimary;
  final Color textSec;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onChannelTap;

  const _VideoTile({
    required this.video,
    required this.ago,
    required this.textPrimary,
    required this.textSec,
    required this.isDark,
    required this.onTap,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail ──────────────────────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                _Thumb(url: video.thumb),
                // تاغ التصنيف
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      video.tag,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── معلومات ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // أيقونة القناة
                GestureDetector(
                  onTap: onChannelTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? const Color(0xFF272727) : const Color(0xFFE5E5E5),
                    child: Text(
                      video.channel.isNotEmpty ? video.channel[0] : '؟',
                      style: TextStyle(fontSize: 14, color: textPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // عنوان + القناة + التاريخ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onChannelTap,
                        child: Text(
                          '${video.channel}  •  $ago',
                          style: TextStyle(fontSize: 12, color: textSec),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة شبكة (ويندوز) ─────────────────────────────────────────────────────
class _VideoGridCard extends StatelessWidget {
  final _Video video;
  final String ago;
  final Color textPrimary;
  final Color textSec;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onChannelTap;

  const _VideoGridCard({
    required this.video,
    required this.ago,
    required this.textPrimary,
    required this.textSec,
    required this.isDark,
    required this.onTap,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  _Thumb(url: video.thumb),
                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(video.tag,
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3),
          ),
          const SizedBox(height: 3),
          GestureDetector(
            onTap: onChannelTap,
            child: Text('${video.channel}  •  $ago',
                style: TextStyle(fontSize: 11, color: textSec)),
          ),
        ],
      ),
    );
  }
}

// ─── Thumbnail مع fallback ────────────────────────────────────────────────────
class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const ColoredBox(color: Color(0xFF1A1A1A)),
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF1A1A1A),
                child: Icon(Icons.play_circle_outline, color: Colors.white30, size: 40),
              ),
            )
          : const ColoredBox(
              color: Color(0xFF1A1A1A),
              child: Icon(Icons.play_circle_outline, color: Colors.white30, size: 40),
            ),
    );
  }
}
