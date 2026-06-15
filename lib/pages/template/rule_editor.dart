import 'package:flutter/material.dart';

import '../../models/score_rule.dart';
import '../../models/template.dart';

/// 弹出计分规则编辑对话框。
Future<ScoreRule?> showRuleEditor(
  BuildContext context, {
  required Template template,
  ScoreRule? rule,
}) {
  String? categoryId = rule?.categoryId ?? template.categories.first.id;
  bool awarded = rule?.awarded ?? false;
  String? awardLevel = rule?.awardLevel;
  String? rank = rule?.rank;
  String? role = rule?.role;
  final pointsCtrl =
      TextEditingController(text: (rule?.points ?? 1).toString());
  final formKey = GlobalKey<FormState>();

  return showDialog<ScoreRule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Widget optionalDropdown(
          String label,
          List<String> options,
          String? value,
          ValueChanged<String?> onChanged,
        ) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<String?>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('不限')),
                for (final o in options)
                  DropdownMenuItem<String?>(value: o, child: Text(o)),
              ],
              onChanged: onChanged,
            ),
          );
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(rule == null ? '添加计分规则' : '编辑计分规则'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '活动分类'),
                    items: [
                      for (final c in template.categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => categoryId = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('针对已获奖'),
                    value: awarded,
                    onChanged: (v) => setState(() {
                      awarded = v;
                      if (!v) {
                        awardLevel = null;
                        rank = null;
                      }
                    }),
                  ),
                  if (awarded) ...[
                    optionalDropdown('获奖级别', template.awardLevels, awardLevel,
                        (v) => setState(() => awardLevel = v)),
                    optionalDropdown('名次', template.ranks, rank,
                        (v) => setState(() => rank = v)),
                  ],
                  if (template.distinguishRoles)
                    optionalDropdown('角色', template.roles, role,
                        (v) => setState(() => role = v)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pointsCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '分数'),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null ? '请输入有效分数' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (categoryId == null) return;
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  ScoreRule(
                    categoryId: categoryId!,
                    awarded: awarded,
                    awardLevel: awarded ? awardLevel : null,
                    rank: awarded ? rank : null,
                    role: role,
                    points: double.parse(pointsCtrl.text),
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    ),
  );
}
