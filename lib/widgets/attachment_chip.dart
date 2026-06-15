import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attachment.dart';
import '../services/attachment_service.dart';
import '../services/storage_service.dart';

/// 附件芯片：显示文件图标与名称，可点击打开，可选删除。
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    super.key,
    required this.attachment,
    this.onRemove,
  });

  final Attachment attachment;
  final VoidCallback? onRemove;

  IconData get _icon {
    if (attachment.isImage) return Icons.image_outlined;
    switch (attachment.extension) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = AttachmentService(context.read<StorageService>());
    final chip = InputChip(
      avatar: Icon(_icon, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(attachment.displayName, overflow: TextOverflow.ellipsis),
      ),
      onPressed: () => svc.open(attachment),
      onDeleted: onRemove,
      deleteIcon: onRemove == null ? null : const Icon(Icons.close, size: 16),
    );
    return chip;
  }
}
