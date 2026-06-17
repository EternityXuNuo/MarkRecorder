import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/lan_sync_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';

/// 配对信息（局域网主机候选地址列表 + 端口 + 配对码）。
typedef _Conn = ({List<String> hosts, int port, String token});

/// 局域网同步页：一端生成二维码（被连接），另一端扫码或手动连接。
/// 连接后双向合并，两端都成为并集。
class LanSyncPage extends StatefulWidget {
  const LanSyncPage({super.key});

  @override
  State<LanSyncPage> createState() => _LanSyncPageState();
}

class _LanSyncPageState extends State<LanSyncPage> {
  late final LanSyncService _svc;
  LanServerInfo? _info;
  String? _hostStatus;
  bool _busy = false;
  String? _busyLabel;
  Timer? _ipWatch;

  bool get _canScan => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _svc = LanSyncService(context.read<StorageService>());
  }

  @override
  void dispose() {
    _ipWatch?.cancel();
    _svc.stop();
    super.dispose();
  }

  /// 托管期间定时重新解析局域网候选 IP；网络环境变化（切换 Wi-Fi/热点等）时刷新二维码。
  void _startIpWatch() {
    _ipWatch?.cancel();
    _ipWatch = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _info == null) return;
      final ips = await _svc.currentLanIps();
      if (!mounted || _info == null) return;
      if (!listEquals(ips, _info!.ips)) {
        setState(() => _info = _info!.withIps(ips));
      }
    });
  }

  void _stopIpWatch() {
    _ipWatch?.cancel();
    _ipWatch = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('局域网同步')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Tip(),
            const SizedBox(height: 16),
            if (_info == null) ..._menu() else _hostCard(),
            if (_busy)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_busyLabel ?? '处理中…',
                        style: const TextStyle(color: Color(0xFF9AA0A6))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _menu() => [
        _card([
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_2, color: Color(0xFF4C7EF3)),
            title: const Text('生成二维码',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('让另一台设备扫码连接到本机'),
            onTap: _startHost,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF34A853)),
            title: const Text('扫码连接',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_canScan ? '扫描另一台设备的二维码' : '当前平台不支持扫码，请用手动连接'),
            enabled: _canScan,
            onTap: _canScan ? _scanConnect : null,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.keyboard_alt_outlined,
                color: Color(0xFF9AA0A6)),
            title: const Text('手动连接',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('输入对方显示的地址与配对码'),
            onTap: _manualConnect,
          ),
        ]),
      ];

  Widget _hostCard() {
    final info = _info!;
    final addr = info.ips.isEmpty
        ? '未取得局域网地址'
        : info.ips.map((ip) => '$ip:${info.port}').join('\n');
    return _card([
      const Text('等待其它设备扫码连接',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E2E2)),
          ),
          child: QrImageView(
            data: info.toQrPayload(),
            version: QrVersions.auto,
            size: 220,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _kv(info.ips.length > 1 ? '局域网地址（任一可用）' : '局域网地址', addr),
      const SizedBox(height: 8),
      _kv('配对码', info.token),
      if (_hostStatus != null) ...[
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x1434A853),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_hostStatus!,
              style: const TextStyle(
                  color: Color(0xFF1E7E34), fontWeight: FontWeight.w600)),
        ),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          _stopIpWatch();
          await _svc.stop();
          if (mounted) setState(() => _info = null);
        },
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('停止'),
      ),
    ]);
  }

  Widget _kv(String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$k：',
              style: const TextStyle(
                  color: Color(0xFF5F6368), fontWeight: FontWeight.w600)),
          Expanded(
            child: SelectableText(v,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      );

  // ---- 发起端 ----
  Future<void> _startHost() async {
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _busyLabel = '启动中';
    });
    try {
      final info = await _svc.startServer(
        provideSnapshot: () => app.exportSnapshot(),
        onReceive: (remote) async {
          final r = await app.mergeSnapshot(remote);
          if (mounted) {
            setState(() => _hostStatus =
                '已与一台设备同步：新增 ${r.added}，更新 ${r.updated}，删除 ${r.deleted}');
          }
        },
      );
      setState(() => _info = info);
      _startIpWatch();
    } catch (e) {
      _toast('启动失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- 连接端 ----
  Future<void> _scanConnect() async {
    final conn = await Navigator.of(context).push<_Conn>(
      MaterialPageRoute(builder: (_) => const _ScannerPage()),
    );
    if (conn != null) await _connect(conn);
  }

  Future<void> _manualConnect() async {
    final conn = await showDialog<_Conn>(
      context: context,
      builder: (_) => const _ManualDialog(),
    );
    if (conn != null) await _connect(conn);
  }

  Future<void> _connect(_Conn c) async {
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _busyLabel = '连接中';
    });
    try {
      // 先从候选地址里挑出能连通的那个（即与本机同子网的那块网卡）。
      final host = await _svc.pickReachableHost(hosts: c.hosts, port: c.port);
      if (host == null) {
        _toast('无法连接：请确认两台设备在同一 Wi-Fi/热点下');
        return;
      }
      if (mounted) setState(() => _busyLabel = '同步中');
      // 拉对方快照（顺带落地对方附件）→ 本地合并为并集 → 回传并集给对方。
      final remote = await _svc.pull(host: host, port: c.port, token: c.token);
      final r = await app.mergeSnapshot(remote);
      await _svc.push(
        host: host,
        port: c.port,
        token: c.token,
        snapshot: app.exportSnapshot(),
      );
      _toast('同步完成：新增 ${r.added}，更新 ${r.updated}，删除 ${r.deleted}');
    } catch (e) {
      _toast('同步失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Tip extends StatelessWidget {
  const _Tip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x144C7EF3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi, color: Color(0xFF4C7EF3)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '两台设备需连接同一 Wi-Fi（或同一局域网）。同步会双向合并，'
              '两端记录都会保留，按"较新的为准"。',
              style: TextStyle(color: Color(0xFF34507A), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 扫码页（仅移动端构建）。
class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final conn = LanServerInfo.parse(raw);
      if (conn != null) {
        _handled = true;
        Navigator.of(context).pop<_Conn>(conn);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描二维码')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('将另一台设备的二维码对准取景框',
                  style: TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手动连接对话框：输入地址、端口、配对码。
class _ManualDialog extends StatefulWidget {
  const _ManualDialog();

  @override
  State<_ManualDialog> createState() => _ManualDialogState();
}

class _ManualDialogState extends State<_ManualDialog> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动连接'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hostCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: '地址（IP）', hintText: '192.168.1.5'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '端口'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '配对码'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        FilledButton(
          onPressed: () {
            final host = _hostCtrl.text.trim();
            final port = int.tryParse(_portCtrl.text.trim());
            final token = _codeCtrl.text.trim();
            if (host.isEmpty || port == null || token.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请完整填写地址、端口与配对码')));
              return;
            }
            Navigator.pop<_Conn>(
                context, (hosts: [host], port: port, token: token));
          },
          child: const Text('连接'),
        ),
      ],
    );
  }
}
