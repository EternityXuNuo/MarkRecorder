import 'dart:io' show Platform;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/activity_record.dart';
import '../models/attachment.dart';
import '../models/template.dart';
import '../services/attachment_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import 'attachment_chip.dart';

/// 弹出记录窗口（半屏设计，方便单手操作）。
/// [record] 非空时为编辑模式，[initialYearId] 用于新增时指定默认学年。
Future<void> showRecordSheet(
  BuildContext context, {
  ActivityRecord? record,
  String? initialYearId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecordSheet(record: record, initialYearId: initialYearId),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({this.record, this.initialYearId});

  final ActivityRecord? record;
  final String? initialYearId;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;

  String? _yearId;
  String? _categoryId;
  bool _awarded = false;
  String? _awardLevel;
  String? _rank;
  bool _isTeam = false;
  String? _role;
  List<Attachment> _attachments = [];
  bool _nameError = false;
  bool _dragging = false;

  /// 桌面端才支持拖拽添加附件。
  bool get _canDrop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _noteCtrl = TextEditingController(text: r?.note ?? '');
    _yearId = r?.yearId ?? widget.initialYearId;
    _categoryId = r?.categoryId;
    _awarded = r?.awarded ?? false;
    _awardLevel = r?.awardLevel;
    _rank = r?.rank;
    _isTeam = r?.isTeam ?? false;
    _role = r?.role;
    _attachments = List.of(r?.attachments ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final template = app.template;
    final years = app.activeYears;
    _yearId ??= app.currentYearId ?? (years.isNotEmpty ? years.first.id : null);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandleAndHeader(context),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('活动名称', required: true),
                    TextField(
                      controller: _nameCtrl,
                      autofocus: widget.record == null,
                      decoration: InputDecoration(
                        hintText: '请输入活动名称',
                        errorText: _nameError ? '活动名称不能为空' : null,
                      ),
                      onChanged: (_) {
                        if (_nameError) setState(() => _nameError = false);
                      },
                    ),
                    const SizedBox(height: 16),
                    _label('学年'),
                    _yearSelector(years),
                    const SizedBox(height: 16),
                    _label('活动分类'),
                    _categorySelector(template),
                    _categoryHint(template),
                    const SizedBox(height: 16),
                    _awardSection(template),
                    const SizedBox(height: 16),
                    _label('附件'),
                    _attachmentSection(),
                    const SizedBox(height: 16),
                    _label('备注'),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(hintText: '可填写补充说明（选填）'),
                    ),
                  ],
                ),
              ),
            ),
            _buildSaveBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHandleAndHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            children: [
              Text(
                widget.record == null ? '添加活动记录' : '编辑活动记录',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: '取消',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Color(0xFF9AA0A6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xFF5F6368),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          children: [
            if (required)
              const TextSpan(
                  text: ' *', style: TextStyle(color: Color(0xFFEA4335))),
          ],
        ),
      ),
    );
  }

  Widget _yearSelector(List years) {
    if (years.isEmpty) {
      return const Text('暂无可用学年，请先在记录页新建学年',
          style: TextStyle(color: Color(0xFF9AA0A6)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final y in years)
          ChoiceChip(
            label: Text(y.name),
            selected: _yearId == y.id,
            onSelected: (_) => setState(() => _yearId = y.id),
          ),
      ],
    );
  }

  Widget _categorySelector(Template template) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('未分类'),
          selected: _categoryId == null,
          onSelected: (_) => setState(() => _categoryId = null),
        ),
        for (final c in template.categories)
          ChoiceChip(
            avatar:
                CircleAvatar(radius: 6, backgroundColor: Color(c.color)),
            label: Text(c.name),
            selected: _categoryId == c.id,
            onSelected: (_) => setState(() => _categoryId = c.id),
          ),
      ],
    );
  }

  Widget _categoryHint(Template template) {
    final cat = template.categoryById(_categoryId);
    if (cat?.hint == null || cat!.hint!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 15, color: Color(0xFF9AA0A6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(cat.hint!,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF9AA0A6))),
          ),
        ],
      ),
    );
  }

  Widget _awardSection(Template template) {
    final levels = template.awardLevels;
    final ranks = template.ranks;
    final roles = template.roles;
    final distinguish = template.distinguishRoles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _label('是否获奖'),
            const Spacer(),
            Switch(
              value: _awarded,
              onChanged: (v) => setState(() {
                _awarded = v;
                if (!v) {
                  _awardLevel = null;
                  _rank = null;
                }
              }),
            ),
          ],
        ),
        if (_awarded) ...[
          const SizedBox(height: 4),
          _label('获奖等级'),
          _wrapChoice(levels, _awardLevel, (v) => setState(() => _awardLevel = v)),
          const SizedBox(height: 12),
          _label('名次'),
          _wrapChoice(ranks, _rank, (v) => setState(() => _rank = v)),
          if (distinguish) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _label('团队荣誉'),
                const Spacer(),
                Switch(
                  value: _isTeam,
                  onChanged: (v) => setState(() {
                    _isTeam = v;
                    if (!v) _role = null;
                  }),
                ),
              ],
            ),
            if (_isTeam) ...[
              const SizedBox(height: 4),
              _label('我的角色'),
              _wrapChoice(roles, _role, (v) => setState(() => _role = v)),
            ],
          ],
        ],
      ],
    );
  }

  Widget _wrapChoice(
      List<String> options, String? selected, ValueChanged<String?> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: selected == o,
            onSelected: (_) => onPick(o),
          ),
      ],
    );
  }

  Widget _attachmentSection() {
    final storage = context.read<StorageService>();
    final svc = AttachmentService(storage);

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in _attachments)
          AttachmentChip(
            attachment: a,
            onRemove: () => setState(() => _attachments.remove(a)),
          ),
        ActionChip(
          avatar: const Icon(Icons.attach_file, size: 18),
          label: const Text('添加附件'),
          onPressed: () async {
            final picked = await svc.pickAndImport();
            if (picked.isNotEmpty) {
              setState(() => _attachments.addAll(picked));
            }
          },
        ),
      ],
    );

    // 移动端/Web：仅展示选择按钮与已选附件。
    if (!_canDrop) return chips;

    // 桌面端：套一层拖拽放置区，拖入文件即导入。
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) async {
        setState(() => _dragging = false);
        final paths = detail.files.map((f) => f.path).toList();
        final imported = await svc.importPaths(paths);
        if (imported.isNotEmpty) {
          setState(() => _attachments.addAll(imported));
        }
        final skipped = paths.length - imported.length;
        if (skipped > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已忽略 $skipped 个不支持的文件')),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _dragging ? const Color(0x144C7EF3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _dragging ? const Color(0xFF4C7EF3) : const Color(0xFFE2E2E2),
            width: _dragging ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            chips,
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.file_download_outlined,
                    size: 16,
                    color: _dragging
                        ? const Color(0xFF4C7EF3)
                        : const Color(0xFF9AA0A6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _dragging ? '松开以添加文件' : '也可将文件拖拽到此处添加',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _dragging
                          ? const Color(0xFF4C7EF3)
                          : const Color(0xFF9AA0A6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _save,
            child: Text(widget.record == null ? '保存记录' : '保存修改'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      HapticFeedback.lightImpact();
      return;
    }
    if (_yearId == null) return;
    HapticFeedback.selectionClick();

    final app = context.read<AppState>();
    final note = _noteCtrl.text.trim();

    if (widget.record == null) {
      final record = ActivityRecord(
        id: app.newId(),
        name: name,
        yearId: _yearId!,
        categoryId: _categoryId,
        awarded: _awarded,
        awardLevel: _awarded ? _awardLevel : null,
        rank: _awarded ? _rank : null,
        isTeam: _isTeam,
        role: _isTeam ? _role : null,
        attachments: _attachments,
        note: note.isEmpty ? null : note,
        createdAt: DateTime.now(),
      );
      await app.addRecord(record);
    } else {
      final updated = ActivityRecord(
        id: widget.record!.id,
        name: name,
        yearId: _yearId!,
        categoryId: _categoryId,
        awarded: _awarded,
        awardLevel: _awarded ? _awardLevel : null,
        rank: _awarded ? _rank : null,
        isTeam: _isTeam,
        role: _isTeam ? _role : null,
        attachments: _attachments,
        note: note.isEmpty ? null : note,
        createdAt: widget.record!.createdAt,
      );
      await app.updateRecord(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
