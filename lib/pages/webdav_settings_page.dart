import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/backup_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';

/// WebDAV 备份设置页：配置服务器、测试连接、备份与恢复。
class WebdavSettingsPage extends StatefulWidget {
  const WebdavSettingsPage({super.key});

  @override
  State<WebdavSettingsPage> createState() => _WebdavSettingsPageState();
}

class _WebdavSettingsPageState extends State<WebdavSettingsPage> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _busy = false;
  String? _busyLabel;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsState>();
    _urlCtrl = TextEditingController(text: s.webdavUrl);
    _userCtrl = TextEditingController(text: s.webdavUser);
    _passCtrl = TextEditingController(text: s.webdavPass);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV 备份')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card([
              _field('服务器地址', _urlCtrl,
                  hint: 'https://dav.example.com/dav/',
                  keyboard: TextInputType.url),
              const SizedBox(height: 12),
              _field('账号', _userCtrl),
              const SizedBox(height: 12),
              _field('密码', _passCtrl, obscure: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _run('测试连接', _test),
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      // 与左侧「测试连接」(OutlinedButton) 的尺寸/圆角保持一致：
                      // 覆盖主题里 FilledButton 的圆角矩形与较大内边距，改用 M3 默认胶囊形。
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        minimumSize: const Size(64, 40),
                        padding:
                            const EdgeInsetsDirectional.only(start: 16, end: 24),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存配置'),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            if (settings.lastBackup != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8),
                child: Text(
                  '上次备份：${DateFormat('yyyy-MM-dd HH:mm').format(settings.lastBackup!)}',
                  style: const TextStyle(color: Color(0xFF9AA0A6)),
                ),
              ),
            _card([
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_upload_outlined,
                    color: Color(0xFF4C7EF3)),
                title: const Text('立即备份',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('将模板、记录与附件上传到 WebDAV'),
                onTap: () => _run('备份中', _backup),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined,
                    color: Color(0xFF34A853)),
                title: const Text('从云端恢复',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('与云端数据合并，或用云端数据覆盖本地'),
                onTap: _confirmRestore,
              ),
            ]),
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

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, bool obscure = false, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF5F6368),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  BackupService get _service =>
      BackupService(context.read<StorageService>());

  Future<void> _save() async {
    await context.read<SettingsState>().saveWebdav(
          url: _urlCtrl.text,
          user: _userCtrl.text,
          pass: _passCtrl.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_urlCtrl.text.trim().isEmpty) {
      _toast('请先填写服务器地址');
      return;
    }
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await action();
      if (mounted) _toast('$label完成');
    } catch (e) {
      if (mounted) _toast('$label失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() => _service.testConnection(
      _urlCtrl.text.trim(), _userCtrl.text.trim(), _passCtrl.text);

  Future<void> _backup() async {
    await _save();
    await _service.backup(
      url: _urlCtrl.text.trim(),
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text,
    );
    if (mounted) {
      await context.read<SettingsState>().setLastBackup(DateTime.now());
    }
  }

  Future<void> _confirmRestore() async {
    final mode = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('从云端恢复'),
        content: const Text(
            '合并：将云端与本地数据按"较新的为准"合并，两端的记录都会保留（推荐）。\n\n'
            '覆盖：用云端数据完全替换本地的模板、记录与附件，本地多出的内容会丢失。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'overwrite'),
              child: const Text('覆盖')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'merge'),
              child: const Text('合并')),
        ],
      ),
    );
    if (mode == 'overwrite') {
      await _run('恢复中', () async {
        await _service.restore(
          url: _urlCtrl.text.trim(),
          user: _userCtrl.text.trim(),
          pass: _passCtrl.text,
        );
        if (mounted) await context.read<AppState>().load();
      });
    } else if (mode == 'merge') {
      if (_urlCtrl.text.trim().isEmpty) {
        _toast('请先填写服务器地址');
        return;
      }
      setState(() {
        _busy = true;
        _busyLabel = '合并中';
      });
      try {
        final msg = await _mergeFromCloud();
        if (mounted) _toast(msg);
      } catch (e) {
        if (mounted) _toast('合并失败：$e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<String> _mergeFromCloud() async {
    final app = context.read<AppState>();
    final url = _urlCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    final remote = await _service.fetchSnapshot(
      url: url,
      user: user,
      pass: pass,
      fallbackTemplate: app.template,
    );
    final result = await app.mergeSnapshot(remote);
    // 仅补齐本地缺失的附件。
    await _service.downloadAttachments(
      result.neededAttachments,
      url: url,
      user: user,
      pass: pass,
    );
    // 合并后回传一次，使云端也成为两端的并集。
    await _service.backup(url: url, user: user, pass: pass);
    if (mounted) {
      await context.read<SettingsState>().setLastBackup(DateTime.now());
    }
    return '合并完成：新增 ${result.added}，更新 ${result.updated}，删除 ${result.deleted}（已回传云端）';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
