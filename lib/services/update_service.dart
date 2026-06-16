import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// 检测更新：读取本机版本，查询 GitHub 最新 release，比较版本号。
class UpdateService {
  static const _repo = 'EternityXuNuo/MarkRecorder';
  static const _api =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// 最新 release 页面（供用户前往下载）。
  static const releasesUrl =
      'https://github.com/$_repo/releases/latest';

  /// 检测更新；网络或解析失败时抛异常。
  Future<UpdateInfo> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version; // 形如 1.1.0
    final latest = await _fetchLatestTag();
    return UpdateInfo(
      current: current,
      latest: latest,
      hasUpdate: _compare(latest, current) > 0,
    );
  }

  Future<String> _fetchLatestTag() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(_api));
      // GitHub API 要求带 User-Agent，否则返回 403。
      req.headers.set(HttpHeaders.userAgentHeader, 'MarkRecorder-App');
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        throw Exception('GitHub 返回 ${resp.statusCode}');
      }
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.trim();
      if (tag == null || tag.isEmpty) throw Exception('未找到版本号');
      return _normalize(tag);
    } finally {
      client.close(force: true);
    }
  }

  /// 去掉 tag 的 v/V 前缀，得到纯版本号。
  static String _normalize(String tag) {
    final t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) return t.substring(1);
    return t;
  }

  /// 语义版本比较：a>b 返回正，a<b 返回负，相等返回 0。
  /// 仅比较点分数字部分，忽略 +构建号 等后缀。
  static int _compare(String a, String b) {
    List<int> parse(String s) => s
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((x) => int.tryParse(x.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

class UpdateInfo {
  final String current;
  final String latest;
  final bool hasUpdate;

  const UpdateInfo({
    required this.current,
    required this.latest,
    required this.hasUpdate,
  });
}
