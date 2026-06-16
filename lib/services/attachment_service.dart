import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import 'storage_service.dart';

/// 附件管理：选择、复制到应用目录、打开、删除。
/// 支持图片、pdf、doc/docx、xlsx/xls、zip 等格式。
class AttachmentService {
  AttachmentService(this._storage);

  final StorageService _storage;
  final _uuid = const Uuid();

  static const allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'zip',
  ];

  /// 选择文件并复制到附件目录，返回新建的 Attachment 列表。
  /// Web 平台无文件系统，附件功能不可用（返回空列表）。
  Future<List<Attachment>> pickAndImport() async {
    if (kIsWeb) return [];
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result == null) return [];
    return importPaths(result.files.map((f) => f.path).whereType<String>());
  }

  /// 从文件路径导入（桌面端拖拽添加附件用）。
  /// 仅接受 [allowedExtensions] 内的扩展名，其余忽略。返回新建的 Attachment。
  Future<List<Attachment>> importPaths(Iterable<String> paths) async {
    if (kIsWeb) return [];
    final dir = await _storage.attachmentsDir();
    final imported = <Attachment>[];
    for (final path in paths) {
      final name = p.basename(path);
      final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
      if (!allowedExtensions.contains(ext)) continue;
      final src = File(path);
      if (!await src.exists()) continue;
      final id = _uuid.v4();
      final storedName = '$id.$ext';
      final dest = File(p.join(dir.path, storedName));
      await src.copy(dest.path);
      imported.add(Attachment(
        id: id,
        storedName: storedName,
        displayName: name,
        extension: ext,
        sizeBytes: await dest.length(),
        addedAt: DateTime.now(),
      ));
    }
    return imported;
  }

  Future<File> fileOf(Attachment a) async {
    final dir = await _storage.attachmentsDir();
    return File(p.join(dir.path, a.storedName));
  }

  Future<void> open(Attachment a) async {
    final file = await fileOf(a);
    await OpenFilex.open(file.path);
  }

  Future<void> delete(Attachment a) async {
    final file = await fileOf(a);
    if (await file.exists()) await file.delete();
  }
}
