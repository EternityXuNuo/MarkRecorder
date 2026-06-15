import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 导入/导出工具：保存与读取 JSON 文件，兼容桌面与移动端。
class ImportExportService {
  /// 保存文本到用户选择的位置。返回保存路径（取消则为 null）。
  static Future<String?> saveJson(String fileName, String content) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final path = await FilePicker.saveFile(
      dialogTitle: '导出',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) return null;
    // 桌面端 saveFile 仅返回路径，需自行写入；移动端已通过 bytes 写好。
    final f = File(path);
    if (!await f.exists() || (await f.length()) == 0) {
      await f.writeAsBytes(bytes);
    }
    return path;
  }

  /// 选择并读取一个 JSON 文件内容。
  static Future<String?> pickJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) return utf8.decode(file.bytes!);
    if (file.path != null) return File(file.path!).readAsString();
    return null;
  }
}
