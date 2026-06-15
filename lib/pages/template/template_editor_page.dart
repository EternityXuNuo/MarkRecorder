import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../models/score_rule.dart';
import '../../models/template.dart';
import '../../services/import_export_service.dart';
import '../../state/app_state.dart';
import 'category_editor.dart';
import 'rule_editor.dart';
import 'string_list_editor.dart';

/// 模板设置页：可视化编辑模板，并支持导入/导出。
class TemplateEditorPage extends StatefulWidget {
  const TemplateEditorPage({super.key});

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late Template _t;
  late TextEditingController _nameCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _t = context.read<AppState>().template;
    _nameCtrl = TextEditingController(text: _t.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _update(Template next) {
    setState(() {
      _t = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final next = _t.copyWith(
      name: _nameCtrl.text.trim().isEmpty ? '未命名模板' : _nameCtrl.text.trim(),
      version: _t.version + 1,
    );
    await context.read<AppState>().updateTemplate(next);
    if (mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('模板已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模板设置'),
        actions: [
          IconButton(
            tooltip: '导入模板',
            onPressed: _import,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: '导出模板',
            onPressed: _export,
            icon: const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _groupTitle('基本信息'),
          _card([
            _textField('模板名称', _nameCtrl),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('区分角色',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('团队荣誉时需选择个人角色'),
              value: _t.distinguishRoles,
              onChanged: (v) => _update(_t.copyWith(distinguishRoles: v)),
            ),
          ]),
          _groupTitle('活动分类'),
          _card([_buildCategories()]),
          _groupTitle('获奖级别'),
          _card([
            StringListEditor(
              values: _t.awardLevels,
              hint: '添加获奖级别',
              onChanged: (v) => _update(_t.copyWith(awardLevels: v)),
            )
          ]),
          _groupTitle('名次'),
          _card([
            StringListEditor(
              values: _t.ranks,
              hint: '添加名次',
              onChanged: (v) => _update(_t.copyWith(ranks: v)),
            )
          ]),
          _groupTitle('角色'),
          _card([
            StringListEditor(
              values: _t.roles,
              hint: '添加角色',
              onChanged: (v) => _update(_t.copyWith(roles: v)),
            )
          ]),
          _groupTitle('计分规则'),
          _card([_buildRules()]),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      children: [
        for (final c in _t.categories)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
                radius: 12, backgroundColor: Color(c.color)),
            title: Text(c.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('学年上限 ${formatNum(c.yearCap)}'
                '${c.hint != null && c.hint!.isNotEmpty ? ' · ${c.hint}' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editCategory(c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteCategory(c),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _editCategory(null),
            icon: const Icon(Icons.add),
            label: const Text('添加分类'),
          ),
        ),
        const Divider(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text('学年分数上限（各分类上限之和）',
                  style: TextStyle(
                      color: Color(0xFF5F6368),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
            Text('${formatNum(_t.yearScoreCap)} 分',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4C7EF3))),
          ],
        ),
      ],
    );
  }

  Future<void> _editCategory(ActivityCategory? cat) async {
    final result = await showCategoryEditor(context, category: cat);
    if (result == null) return;
    if (cat == null) {
      final added = result.copyWith();
      _update(_t.copyWith(categories: [..._t.categories, added]));
    } else {
      _update(_t.copyWith(
        categories:
            _t.categories.map((c) => c.id == result.id ? result : c).toList(),
      ));
    }
  }

  void _deleteCategory(ActivityCategory cat) {
    _update(_t.copyWith(
      categories: _t.categories.where((c) => c.id != cat.id).toList(),
      scoreRules:
          _t.scoreRules.where((r) => r.categoryId != cat.id).toList(),
    ));
  }

  Widget _buildRules() {
    return Column(
      children: [
        if (_t.scoreRules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('暂无计分规则',
                style: TextStyle(color: Color(0xFF9AA0A6))),
          ),
        for (var i = 0; i < _t.scoreRules.length; i++)
          _ruleTile(_t.scoreRules[i], i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _t.categories.isEmpty ? null : () => _editRule(null, -1),
            icon: const Icon(Icons.add),
            label: const Text('添加规则'),
          ),
        ),
      ],
    );
  }

  Widget _ruleTile(ScoreRule r, int index) {
    final cat = _t.categoryById(r.categoryId);
    final parts = <String>[
      cat?.name ?? '未知分类',
      r.awarded ? '获奖' : '未获奖',
      if (r.awardLevel != null) r.awardLevel!,
      if (r.rank != null) r.rank!,
      if (r.role != null) r.role!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 12,
        backgroundColor:
            cat != null ? Color(cat.color) : const Color(0xFFCBD2DD),
      ),
      title: Text(parts.join(' · '), style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${formatNum(r.points)}分',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF4C7EF3))),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editRule(r, index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _update(_t.copyWith(
                scoreRules: [..._t.scoreRules]..removeAt(index))),
          ),
        ],
      ),
    );
  }

  Future<void> _editRule(ScoreRule? rule, int index) async {
    final result = await showRuleEditor(context, template: _t, rule: rule);
    if (result == null) return;
    if (rule == null) {
      _update(_t.copyWith(scoreRules: [..._t.scoreRules, result]));
    } else {
      final list = [..._t.scoreRules];
      list[index] = result;
      _update(_t.copyWith(scoreRules: list));
    }
  }

  // ---- 导入 / 导出 ----
  Future<void> _export() async {
    final content =
        const JsonEncoder.withIndent('  ').convert(_t.toJson());
    final path = await ImportExportService.saveJson(
        '${_t.name}.template.json', content);
    if (mounted && path != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导出到 $path')));
    }
  }

  Future<void> _import() async {
    final content = await ImportExportService.pickJson();
    if (content == null) return;
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final imported = Template.fromJson(json);
      setState(() {
        _t = imported;
        _nameCtrl.text = imported.name;
        _dirty = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已导入模板，点击保存以生效')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$e')));
      }
    }
  }

  // ---- 小工具 ----
  Widget _groupTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t,
            style: const TextStyle(
                color: Color(0xFF9AA0A6),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _textField(String label, TextEditingController ctrl,
      {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF5F6368),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          onChanged: (_) => setState(() => _dirty = true),
        ),
      ],
    );
  }
}

/// 格式化数字：去掉无意义的小数点。
String formatNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}
