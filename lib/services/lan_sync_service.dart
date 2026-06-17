import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'merge_service.dart';
import 'storage_service.dart';

/// 局域网同步：发起端开一个临时 HTTP 服务并展示二维码（或手动配对码），
/// 连接端扫码后拉取对方快照、合并、再回传，使两端都成为并集。
///
/// 协议（私有，仅本 App 间用）：
///   GET  /snapshot  请求头 x-sync-token 校验 → 返回 zip（snapshot.json + attachments/*）
///   POST /snapshot  请求头 x-sync-token 校验，body 为同样的 zip → 服务端合并
class LanSyncService {
  LanSyncService(this._storage);

  final StorageService _storage;

  HttpServer? _server;

  bool get isServing => _server != null;

  /// 启动发起端服务。[provideSnapshot] 提供本机当前快照；[onReceive] 在收到
  /// 连接端回传的快照后被调用（页面在此执行 AppState 合并并刷新 UI）。
  Future<LanServerInfo> startServer({
    required SyncSnapshot Function() provideSnapshot,
    required Future<void> Function(SyncSnapshot remote) onReceive,
  }) async {
    await stop();
    final token = _genCode();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;

    server.listen((req) async {
      final res = req.response;
      try {
        if (req.headers.value('x-sync-token') != token) {
          res.statusCode = HttpStatus.unauthorized;
          await res.close();
          return;
        }
        if (req.method == 'GET' && req.uri.path == '/snapshot') {
          final pkg = await _buildPackage(provideSnapshot());
          res.headers.contentType = ContentType('application', 'zip');
          res.add(pkg);
          await res.close();
        } else if (req.method == 'POST' && req.uri.path == '/snapshot') {
          final body = await _collect(req);
          final remote = await _ingestPackage(body);
          await onReceive(remote);
          res.statusCode = HttpStatus.ok;
          await res.close();
        } else {
          res.statusCode = HttpStatus.notFound;
          await res.close();
        }
      } catch (e) {
        try {
          res.statusCode = HttpStatus.internalServerError;
          res.write('$e');
          await res.close();
        } catch (_) {/* 连接已断开 */}
      }
    });

    return LanServerInfo(
        ips: await _privateCandidates(), port: server.port, token: token);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// 连接端：拉取发起端快照（顺带把对方附件落到本地），返回解析出的快照。
  Future<SyncSnapshot> pull({
    required String host,
    required int port,
    required String token,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(Uri(scheme: 'http', host: host, port: port, path: '/snapshot'));
      req.headers.set('x-sync-token', token);
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        throw Exception('对方返回 ${resp.statusCode}');
      }
      return _ingestPackage(await _collectResponse(resp));
    } finally {
      client.close(force: true);
    }
  }

  /// 连接端：把本机（已合并为并集的）快照回传给发起端。
  Future<void> push({
    required String host,
    required int port,
    required String token,
    required SyncSnapshot snapshot,
  }) async {
    final pkg = await _buildPackage(snapshot);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(
          Uri(scheme: 'http', host: host, port: port, path: '/snapshot'));
      req.headers.set('x-sync-token', token);
      req.headers.contentType = ContentType('application', 'zip');
      req.add(pkg);
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) {
        throw Exception('对方返回 ${resp.statusCode}');
      }
      await resp.drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  // ---- 打包 / 解包 ----
  Future<Uint8List> _buildPackage(SyncSnapshot s) async {
    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(s.toJson()));
    archive.addFile(ArchiveFile('snapshot.json', jsonBytes.length, jsonBytes));

    final dir = await _storage.attachmentsDir();
    final names = <String>{
      for (final r in s.records)
        for (final a in r.attachments) a.storedName,
    };
    for (final name in names) {
      final f = File(p.join(dir.path, name));
      if (!await f.exists()) continue;
      final b = await f.readAsBytes();
      archive.addFile(ArchiveFile('attachments/$name', b.length, b));
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  Future<SyncSnapshot> _ingestPackage(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final dir = await _storage.attachmentsDir();
    SyncSnapshot? snapshot;
    for (final f in archive) {
      if (!f.isFile) continue;
      if (f.name == 'snapshot.json') {
        snapshot = SyncSnapshot.fromJson(
            jsonDecode(utf8.decode(f.content as List<int>))
                as Map<String, dynamic>);
      } else if (f.name.startsWith('attachments/')) {
        final name = f.name.substring('attachments/'.length);
        if (name.isEmpty) continue;
        final out = File(p.join(dir.path, name));
        if (await out.exists()) continue; // 本地已有，跳过
        await out.writeAsBytes(f.content as List<int>);
      }
    }
    if (snapshot == null) throw Exception('数据包缺少 snapshot.json');
    return snapshot;
  }

  Future<Uint8List> _collect(HttpRequest req) async {
    final chunks = <int>[];
    await for (final c in req) {
      chunks.addAll(c);
    }
    return Uint8List.fromList(chunks);
  }

  Future<Uint8List> _collectResponse(HttpClientResponse resp) async {
    final chunks = <int>[];
    await for (final c in resp) {
      chunks.addAll(c);
    }
    return Uint8List.fromList(chunks);
  }

  /// 重新解析本机当前的全部局域网候选 IPv4（网络环境变化后用于刷新二维码）。
  /// 服务绑定在 anyIPv4，任意网卡上的连接都能收，故无需在主机侧猜“哪个 IP 对”——
  /// 把全部候选都放进二维码，由对端逐个试连，能连通的那个（即同子网的那块）自然胜出。
  Future<List<String>> currentLanIps() => _privateCandidates();

  /// 连接端：在候选地址里挑出第一个能连通的主机。
  ///
  /// “该用哪个 IP”本质上只有对端能裁定——只有与对端同子网的地址才能建立 TCP 连接。
  /// 这里对每个候选做一次短超时的 TCP 连接探测（服务端绑在 anyIPv4，可达即连得上），
  /// 首个成功的即为正确地址；不同子网/不可达的地址会被快速跳过。全部失败返回 null。
  Future<String?> pickReachableHost({
    required List<String> hosts,
    required int port,
  }) async {
    for (final h in hosts) {
      Socket? probe;
      try {
        probe = await Socket.connect(h, port,
            timeout: const Duration(milliseconds: 1500));
        return h;
      } catch (_) {
        // 不可达/不同子网，试下一个
      } finally {
        probe?.destroy();
      }
    }
    return null;
  }

  /// 收集本机私网 IPv4，按网卡名评分降序排序；同分再按 IP 字典序，保证结果确定。
  /// 评分（无线/热点 > 有线 > 虚拟）只用于决定对端的“尝试顺序”，让最可能的地址排在
  /// 前面以减少试连次数——正确性由对端的实际连通性裁定，不再依赖评分。
  Future<List<String>> _privateCandidates() async {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    final scored = <({String ip, int score})>[];
    for (final iface in ifaces) {
      final score = _ifaceScore(iface.name);
      for (final addr in iface.addresses) {
        if (_isPrivateV4(addr.address)) {
          scored.add((ip: addr.address, score: score));
        }
      }
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.ip.compareTo(b.ip);
    });
    return [for (final e in scored) e.ip];
  }

  /// 网卡名打分（大小写无关）：无线/热点优先于有线，二者都优先于已知虚拟网卡。
  /// 无线高于有线是为了：手机热点必走无线，且当有线网卡拔线后 IP 仍残留时，回退
  /// 也不会落到那个残留的有线 IP 上。
  static int _ifaceScore(String name) {
    final n = name.toLowerCase();
    const virtual = [
      'vmware', 'virtualbox', 'vbox', 'vethernet', 'hyper-v', 'loopback',
      'tailscale', 'wsl', 'docker', 'bluetooth', 'tap', 'tun', 'zerotier',
      'radmin', 'npcap', 'virtual',
    ];
    const wireless = ['wi-fi', 'wifi', 'wlan', 'wireless', '无线'];
    const wired = ['ethernet', '以太网', 'eth'];
    var score = 0;
    for (final k in virtual) {
      if (n.contains(k)) score -= 100;
    }
    for (final k in wireless) {
      if (n.contains(k)) score += 60;
    }
    for (final k in wired) {
      if (n.contains(k)) score += 50;
    }
    return score;
  }

  /// 是否 IPv4 私网段（192.168 / 10 / 172.16-31）。
  static bool _isPrivateV4(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length < 2) return false;
      final second = int.tryParse(parts[1]) ?? 0;
      return second >= 16 && second <= 31;
    }
    return false;
  }

  /// 6 位数字配对码，便于手动输入，也编入二维码做鉴权。
  static String _genCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }
}

/// 发起端连接信息：全部局域网候选 IP、端口、配对码。
/// 二维码携带全部候选地址，对端逐个试连，无需主机侧猜“哪个 IP 对”。
class LanServerInfo {
  final List<String> ips;
  final int port;
  final String token;

  const LanServerInfo(
      {required this.ips, required this.port, required this.token});

  /// 仅替换候选 IP 列表（端口/配对码不变）；空列表表示当前无可用局域网地址。
  LanServerInfo withIps(List<String> ips) =>
      LanServerInfo(ips: ips, port: port, token: token);

  /// 二维码载荷（私有协议，仅本 App 识别）。`hosts` 为全部候选地址。
  String toQrPayload() => jsonEncode({
        'v': 2,
        'app': 'mark_recoder',
        'hosts': ips,
        'port': port,
        'token': token,
      });

  /// 解析扫描/手动得到的配对信息；非本 App 的二维码返回 null。
  /// 兼容旧版（v1，单个 `host` 字段）与新版（v2，`hosts` 列表）。
  static ({List<String> hosts, int port, String token})? parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['app'] != 'mark_recoder') return null;
      final port = json['port'] as int?;
      final token = json['token'] as String?;
      if (port == null || token == null) return null;
      final hosts = <String>[
        if (json['hosts'] is List)
          for (final h in json['hosts'] as List)
            if (h is String && h.isNotEmpty) h,
        if (json['host'] is String && (json['host'] as String).isNotEmpty)
          json['host'] as String,
      ];
      if (hosts.isEmpty) return null;
      return (hosts: hosts, port: port, token: token);
    } catch (_) {
      return null;
    }
  }
}
