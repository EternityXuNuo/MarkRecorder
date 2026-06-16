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

  /// 取本机局域网 IPv4，优先私有网段（192.168 / 10 / 172.16-31）。
  Future<String?> _lanIp() async {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    String? fallback;
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        fallback ??= ip;
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            _is172Private(ip)) {
          return ip;
        }
      }
    }
    return fallback;
  }

  static bool _is172Private(String ip) {
    if (!ip.startsWith('172.')) return false;
    final parts = ip.split('.');
    if (parts.length < 2) return false;
    final second = int.tryParse(parts[1]) ?? 0;
    return second >= 16 && second <= 31;
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
