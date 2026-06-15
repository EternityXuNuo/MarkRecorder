import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/category.dart';

/// 可选的分类配色（柔和饱和卡片色，参考 Figma）。
const kCategoryPalette = <int>[
  0xFF90D8FF, // 蓝
  0xFFFF9092, // 红
  0xFF909BFF, // 靛蓝
  0xFFF290FF, // 紫
  0xFFFFC890, // 橙
  0xFF90E8C2, // 青绿
  0xFFFFB6D2, // 粉
  0xFFD7E890, // 黄绿
];

/// 弹出分类编辑对话框。返回编辑后的分类（新增时生成新 id）。
Future<ActivityCategory?> showCategoryEditor(
  BuildContext context, {
  ActivityCategory? category,
}) {
  final nameCtrl = TextEditingController(text: category?.name ?? '');
  final capCtrl =
      TextEditingController(text: (category?.yearCap ?? 25).toString());
  final hintCtrl = TextEditingController(text: category?.hint ?? '');
  int color = category?.color ?? kCategoryPalette.first;
  final id = category?.id ?? const Uuid().v4();
  final formKey = GlobalKey<FormState>();

  return showDialog<ActivityCategory>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(category == null ? '添加分类' : '编辑分类'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: capCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '学年总分上限'),
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d <= 0) return '请输入有效上限';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: hintCtrl,
                  decoration: const InputDecoration(
                      labelText: '提示信息（选填）', hintText: '记录时显示给用户的说明'),
                ),
                const SizedBox(height: 16),
                const Text('颜色',
                    style: TextStyle(
                        color: Color(0xFF5F6368),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in kCategoryPalette)
                      GestureDetector(
                        onTap: () => setState(() => color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c
                                  ? const Color(0xFF1A1C1E)
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: color == c
                              ? const Icon(Icons.check,
                                  size: 18, color: Color(0xFF2A2D32))
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                ActivityCategory(
                  id: id,
                  name: nameCtrl.text.trim(),
                  color: color,
                  yearCap: double.parse(capCtrl.text),
                  hint: hintCtrl.text.trim().isEmpty
                      ? null
                      : hintCtrl.text.trim(),
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}
