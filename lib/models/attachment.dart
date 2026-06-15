/// 附件。支持图片、pdf、doc、xlsx、zip 等格式。
/// 文件实际存放在应用文档目录的 attachments 子目录中，这里只保存相对文件名与元信息。
class Attachment {
  final String id;

  /// 存储在 attachments 目录下的文件名（含扩展名）。
  final String storedName;

  /// 原始文件名，用于展示。
  final String displayName;

  /// 扩展名（小写，不含点），用于图标判断：jpg/png/pdf/doc/xlsx/zip…
  final String extension;

  final int sizeBytes;
  final DateTime addedAt;

  const Attachment({
    required this.id,
    required this.storedName,
    required this.displayName,
    required this.extension,
    required this.sizeBytes,
    required this.addedAt,
  });

  bool get isImage =>
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(extension);

  Map<String, dynamic> toJson() => {
        'id': id,
        'storedName': storedName,
        'displayName': displayName,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String,
        storedName: json['storedName'] as String,
        displayName: json['displayName'] as String,
        extension: json['extension'] as String,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}
