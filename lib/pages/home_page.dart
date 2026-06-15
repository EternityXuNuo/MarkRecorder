import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'archive_page.dart';
import 'records_page.dart';
import 'settings_page.dart';

/// 应用主框架：底部悬浮药丸导航在 记录 / 归档 / 设置 三个页面间切换。
/// 样式参考 Figma：白色圆角药丸条，选中项为黑色药丸 + 白字。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = [
    RecordsPage(),
    ArchivePage(),
    SettingsPage(),
  ];

  static const _labels = ['记录', '归档', '设置'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _PillNavBar(
        index: _index,
        labels: _labels,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _PillNavBar extends StatelessWidget {
  const _PillNavBar({
    required this.index,
    required this.labels,
    required this.onSelected,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  static const _animDuration = Duration(milliseconds: 260);
  static const _animCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 48,
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final n = labels.length;
                  final segWidth = constraints.maxWidth / n;
                  // 选中项对应的对齐位置：0→-1（最左），末项→1（最右）。
                  final pillAlign = n <= 1 ? 0.0 : (index / (n - 1)) * 2 - 1;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 单个黑色药丸，切换时在各标签间平滑滑动。
                      AnimatedAlign(
                        duration: _animDuration,
                        curve: _animCurve,
                        alignment: Alignment(pillAlign, 0),
                        child: Container(
                          width: segWidth,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (i != index) {
                                    HapticFeedback.selectionClick();
                                  }
                                  onSelected(i);
                                },
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: _animDuration,
                                    curve: _animCurve,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: i == index
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    child: Text(labels[i]),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
