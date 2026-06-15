import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:webdav_client/webdav_client.dart' as webdav;

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
}
