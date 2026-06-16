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

    return LanServerInfo(ip: await _lanIp(), port: server.port, token: token);
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

  /// 重新解析本机当前局域网 IPv4（网络环境变化后用于刷新二维码）。
  /// 服务绑定在 anyIPv4，IP 变化无需重启服务，只需更新展示值。
  Future<String?> currentLanIp() => _lanIp();

  /// 解析本机“真正接入网络”的那块网卡的 IPv4。
  ///
  /// Windows 上常同时存在多块网卡（VMware / VirtualBox / Hyper-V / WSL / VPN 等
  /// 虚拟网卡的地址也会落在 192.168 / 10 / 172 私网段），简单“枚举到第一个私网
  /// 地址就返回”会经常取到虚拟网卡的错误地址。这里优先借系统路由表定位真正出网
  /// 的网卡：对一个公网地址发起连接（仅触发选路、不真正传输数据），操作系统据路由
  /// 选出的本地源地址即为正确的局域网 IP。无网络时退化为按网卡名排序的启发式枚举。
  Future<String?> _lanIp() async {
    final routed = await _routedSourceIp();
    if (routed != null && _isPrivateV4(routed)) return routed;

    final ranked = await _rankedPrivateIp();
    if (ranked != null) return ranked;

    return routed; // 兜底：即便不在私网段，也好过返回 null
  }

  /// 借系统路由表选出真正出网网卡的源地址：连一个公网地址，读本地端地址。
  /// 仅为触发选路，不依赖对方真正收发数据；失败（离线/被拦截）返回 null。
  Future<String?> _routedSourceIp() async {
    Socket? socket;
    try {
      socket = await Socket.connect('8.8.8.8', 443,
          timeout: const Duration(milliseconds: 700));
      return socket.address.address; // 本地源地址
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// 退化方案：枚举网卡，物理网卡（Wi-Fi / 以太网）优先，已知虚拟网卡靠后。
  Future<String?> _rankedPrivateIp() async {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    String? best;
    var bestScore = -1 << 30;
    for (final iface in ifaces) {
      final score = _ifaceScore(iface.name);
      for (final addr in iface.addresses) {
        if (!_isPrivateV4(addr.address)) continue;
        if (score > bestScore) {
          bestScore = score;
          best = addr.address;
        }
      }
    }
    return best;
  }

  /// 网卡名打分：物理网卡加分，已知虚拟网卡减分（大小写无关）。
  static int _ifaceScore(String name) {
    final n = name.toLowerCase();
    const virtual = [
      'vmware', 'virtualbox', 'vbox', 'vethernet', 'hyper-v', 'loopback',
      'tailscale', 'wsl', 'docker', 'bluetooth', 'tap', 'tun', 'zerotier',
      'radmin', 'npcap', 'virtual',
    ];
    const physical = [
      'wi-fi', 'wifi', 'wlan', 'wireless', '无线', 'ethernet', '以太网', 'eth',
    ];
    var score = 0;
    for (final k in virtual) {
      if (n.contains(k)) score -= 100;
    }
    for (final k in physical) {
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

/// 发起端连接信息：局域网 IP、端口、配对码。
class LanServerInfo {
  final String? ip;
  final int port;
  final String token;

  const LanServerInfo({required this.ip, required this.port, required this.token});

  /// 仅替换 IP（端口/配对码不变）；传 null 表示当前无可用局域网地址。
  LanServerInfo withIp(String? ip) =>
      LanServerInfo(ip: ip, port: port, token: token);

  /// 二维码载荷（私有协议，仅本 App 识别）。
  String toQrPayload() => jsonEncode({
        'v': 1,
        'app': 'mark_recoder',
        'host': ip,
        'port': port,
        'token': token,
      });

  /// 解析扫描/手动得到的配对信息；非本 App 的二维码返回 null。
  static ({String host, int port, String token})? parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['app'] != 'mark_recoder') return null;
      final host = json['host'] as String?;
      final port = json['port'] as int?;
      final token = json['token'] as String?;
      if (host == null || port == null || token == null) return null;
      return (host: host, port: port, token: token);
    } catch (_) {
      return null;
    }
  }
}
