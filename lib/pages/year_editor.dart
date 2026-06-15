import 'package:flutter/material.dart';

/// 弹出学年编辑对话框，仅设置学年名称并返回。
/// 学年分数上限不在此设置——它由模板派生（各分类活动上限之和），请在「设置 > 模板设置」中调整。
Future<String?> showYearEditor(
  BuildContext context, {
  String? initialName,
}) {
  final nameCtrl = TextEditingController(text: initialName ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(initialName == null ? '新建学年' : '重命名学年'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '学年名称',
                hintText: '例如：2024-2025学年',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入学年名称' : null,
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF9AA0A6)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '学年分数上限由模板决定（各分类活动上限之和），可在「设置 > 模板设置」中调整。',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF9AA0A6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(context, nameCtrl.text.trim());
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
