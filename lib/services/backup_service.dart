import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/template.dart';
import 'merge_service.dart';
import 'storage_service.dart';

/// WebDAV 备份服务：将本地数据（模板、记录、附件）打包上传，及从云端恢复。
/// 备份目录结构：[remoteDir]/template.json、data.json、attachments/*
class BackupService {
  BackupService(this._storage);

  final StorageService _storage;
  static const remoteDir = 'mark_recoder';

  webdav.Client _client(String url, String user, String pass) {
    return webdav.newClient(url, user: user, password: pass);
  }

  /// 测试连接。
  Future<void> testConnection(String url, String user, String pass) async {
    await _client(url, user, pass).ping();
  }

  /// 备份到 WebDAV。
  Future<void> backup({
    required String url,
    required String user,
    required String pass,
  }) async {
    final client = _client(url, user, pass);
    await client.mkdirAll(remoteDir);

    final base = await _storage.baseDir;
    final template = File(p.join(base.path, 'template.json'));
    final data = File(p.join(base.path, 'data.json'));

    if (await template.exists()) {
      await client.writeFromFile(template.path, '$remoteDir/template.json');
    }
    if (await data.exists()) {
      await client.writeFromFile(data.path, '$remoteDir/data.json');
    }

    // 附件
    final attachDir = await _storage.attachmentsDir();
    await client.mkdirAll('$remoteDir/attachments');
    await for (final entity in attachDir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        await client.writeFromFile(
            entity.path, '$remoteDir/attachments/$name');
      }
    }
  }

  /// 从 WebDAV 恢复（覆盖本地数据）。
  Future<void> restore({
    required String url,
    required String user,
    required String pass,
  }) async {
    final client = _client(url, user, pass);
    final base = await _storage.baseDir;

    Future<void> pull(String remote, String localName) async {
      try {
        await client.read2File('$remoteDir/$remote', p.join(base.path, localName));
      } catch (_) {
        // 远端可能不存在该文件，忽略。
      }
    }

    await pull('template.json', 'template.json');
    await pull('data.json', 'data.json');

    // 附件
    try {
      final files = await client.readDir('$remoteDir/attachments');
      final attachDir = await _storage.attachmentsDir();
      for (final f in files) {
        if (f.isDir == true || f.name == null) continue;
        await client.read2File(
          '$remoteDir/attachments/${f.name}',
          p.join(attachDir.path, f.name!),
        );
      }
    } catch (_) {
      // 远端无附件目录。
    }
  }

  /// 读取云端快照到内存（不落地、不覆盖本地），供"合并"恢复使用。
  /// 远端缺 template.json 时退回 [fallbackTemplate]（其时间戳与本地相同，
  /// 合并时按"较新者胜"自然保留本地模板）。
  Future<SyncSnapshot> fetchSnapshot({
    required String url,
    required String user,
    required String pass,
    required Template fallbackTemplate,
  }) async {
    final client = _client(url, user, pass);

    Template template = fallbackTemplate;
    try {
      final bytes = await client.read('$remoteDir/template.json');
      template = Template.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (_) {
      // 远端无模板，沿用本地。
    }

    var data = const DataBundle.empty();
    try {
      final bytes = await client.read('$remoteDir/data.json');
      data = DataBundle.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    } catch (_) {
      // 远端无数据。
    }

    return SyncSnapshot(
      template: template,
      years: data.years,
      records: data.records,
      deletedYears: data.deletedYears,
      deletedRecords: data.deletedRecords,
    );
  }

  /// 从云端下载指定附件到本地附件目录。[skipExisting] 为真时跳过本地已存在的，
  /// 合并恢复只需补齐本地缺失的附件。
  Future<void> downloadAttachments(
    Iterable<String> storedNames, {
    required String url,
    required String user,
    required String pass,
    bool skipExisting = true,
  }) async {
    final client = _client(url, user, pass);
    final attachDir = await _storage.attachmentsDir();
    for (final name in storedNames) {
      final f = File(p.join(attachDir.path, name));
      if (skipExisting && await f.exists()) continue;
      try {
        await client.read2File('$remoteDir/attachments/$name', f.path);
      } catch (_) {
        // 单个附件缺失或失败，跳过，不中断整体合并。
      }
    }
  }
}
