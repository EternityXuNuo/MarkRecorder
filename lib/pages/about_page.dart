import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

/// 关于页面：软件声明、版本、检测更新。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final result = await UpdateService().check();
      if (!mounted) return;
      if (result.hasUpdate) {
        _showUpdateDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前已是最新版本（v${result.current}）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('检测失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text('当前版本 v${info.current}，最新版本 v${info.latest}。\n是否前往下载？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openReleases();
            },
            child: const Text('前往下载'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReleases() async {
    final uri = Uri.parse(UpdateService.releasesUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开浏览器，请手动访问：${UpdateService.releasesUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C7EF3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.checklist_rtl,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '综测笺',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _version.isEmpty ? '版本 —' : '版本 $_version',
                  style: const TextStyle(color: Color(0xFF9AA0A6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _card(
            title: '软件声明',
            child: const Text(
              '所有数据默认存储在本设备，云端仅用于备份与跨平台同步。'
              '请妥善保管您的备份凭据与数据。',
              style: TextStyle(height: 1.6, color: Color(0xFF5F6368)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.system_update_outlined,
                color: Color(0xFF4C7EF3),
              ),
              title: const Text(
                '检测更新',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('与 GitHub 最新发布版本比较'),
              trailing: _checking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _checking ? null : _checkUpdate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
