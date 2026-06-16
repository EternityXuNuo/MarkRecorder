import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/excel_export_service.dart';
import '../services/import_export_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import 'about_page.dart';
import 'lan_sync_page.dart';
import 'template/template_editor_page.dart';
import 'webdav_settings_page.dart';

/// 设置页面：模板设置、备份设置、（服务器设置-暂不做）、关于。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
        children: [
          _section('模板', [
            _item(
              context,
              icon: Icons.dashboard_customize_outlined,
              title: '模板设置',
              subtitle: '编辑、导入或导出综测模板',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemplateEditorPage()),
              ),
            ),
          ]),
          _section('备份与数据', [
            _item(
              context,
              icon: Icons.cloud_sync_outlined,
              title: 'WebDAV 备份',
              subtitle: '配置备份服务器，备份或恢复数据',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebdavSettingsPage()),
              ),
            ),
            _item(
              context,
              icon: Icons.sync_alt,
              title: '局域网同步',
              subtitle: '同一 Wi-Fi 下扫码，与另一台设备双向合并',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanSyncPage()),
              ),
            ),
            _item(
              context,
              icon: Icons.import_export,
              title: '数据导入/导出',
              subtitle: '将全部数据导出为文件，或从文件导入',
              onTap: () => _showDataSheet(context),
            ),
            _item(
              context,
              icon: Icons.table_view_outlined,
              title: '导出 Excel 表格',
              subtitle: '导出明细表格；含附件时连同附件打包为 zip',
              onTap: () => _exportExcel(context),
            ),
          ]),
          _section('其他', [
            _item(
              context,
              icon: Icons.dns_outlined,
              title: '服务器设置',
              subtitle: '联网模式（开发中）',
              enabled: false,
              onTap: () {},
            ),
            _item(
              context,
              icon: Icons.info_outline,
              title: '关于',
              subtitle: '软件声明、检测更新',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showDataSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('数据导入/导出',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            _sheetItem(
              icon: Icons.file_upload_outlined,
              color: const Color(0xFF4C7EF3),
              title: '导出全部数据',
              subtitle: '包含模板、学年与活动记录',
              onTap: () async {
                Navigator.pop(sheetContext);
                await _exportData(context);
              },
            ),
            _sheetItem(
              icon: Icons.file_download_outlined,
              color: const Color(0xFF34A853),
              title: '导入数据',
              subtitle: '从导出文件恢复（覆盖现有数据）',
              onTap: () async {
                Navigator.pop(sheetContext);
                await _importData(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final content = await app.exportAll();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .substring(0, 15);
    final fileName = '综测数据_$stamp.json';
    final path = await ImportExportService.saveJson(fileName, content);
    if (path != null) {
      messenger.showSnackBar(
          SnackBar(content: Text('已导出：${_savedLocation(fileName, path)}')));
    }
  }

  /// 导出成功提示的位置文案：桌面端 saveFile 返回真实路径，直接显示；
  /// 移动端返回的是 SAF 文档路径（非真实路径，会误导），改为只显示文件名
  /// ——文件已保存到用户在系统保存框中选定的位置。
  static String _savedLocation(String fileName, String path) {
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    return isDesktop ? path : fileName;
  }

  Future<void> _exportExcel(BuildContext context) async {
    final app = context.read<AppState>();
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);
    final svc = ExcelExportService(storage);

    final years = [...app.activeYears, ...app.archivedYears];
    final records = [for (final y in years) ...app.recordsOfYear(y.id)];
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:\-]'), '')
        .substring(0, 13); // yyyyMMddTHHmm
    final xlsxName = '综测记录_$stamp.xlsx';

    try {
      final xlsx = svc.buildWorkbook(
          template: app.template, years: years, records: records);
      final export = await svc.buildExportZip(
        xlsxName: xlsxName,
        xlsxBytes: xlsx,
        years: years,
        records: records,
      );

      if (export.attachmentCount == 0) {
        // 没有附件：直接导出 .xlsx，方便直接打开（只弹一次保存框）。
        final path =
            await ExcelExportService.saveBytes(xlsxName, 'xlsx', xlsx);
        if (path != null) {
          messenger.showSnackBar(SnackBar(
              content: Text('已导出表格（无附件）：${_savedLocation(xlsxName, path)}')));
        }
      } else {
        // 有附件：表格 + 附件合并为一个 zip，只弹一次保存框。
        final zipName = '综测导出_$stamp.zip';
        final path =
            await ExcelExportService.saveBytes(zipName, 'zip', export.bytes);
        if (path != null) {
          messenger.showSnackBar(SnackBar(
              content: Text('已导出：表格 + ${export.attachmentCount} 个附件'
                  '（${_savedLocation(zipName, path)}）')));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _importData(BuildContext context) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('导入数据'),
        content: const Text('导入将覆盖当前全部数据，确定继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('导入')),
        ],
      ),
    );
    if (ok != true) return;
    final content = await ImportExportService.pickJson();
    if (content == null) return;
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      await app.importAll(json);
      messenger.showSnackBar(const SnackBar(content: Text('数据导入成功')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Widget _sheetItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(title,
              style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final tint = enabled ? const Color(0xFF4C7EF3) : const Color(0xFF9AA0A6);
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tint, size: 21),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD2DD)),
      onTap: enabled ? onTap : null,
    );
  }
}
