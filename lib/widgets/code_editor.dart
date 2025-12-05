import 'package:flutter/material.dart';

/// 代码编辑器组件
/// 用于输入 Mermaid 代码
class CodeEditor extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback? onSave;
  final VoidCallback? onFocusLost; // 失去焦点时的回调

  const CodeEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSave,
    this.onFocusLost,
  });

  /// 格式化 Mermaid 代码
  String _formatMermaidCode(String code) {
    final lines = code.split('\n');
    final formattedLines = <String>[];
    int indentLevel = 0;

    // 定义需要增加缩进的关键字
    final increaseIndentKeywords = [
      'graph',
      'flowchart',
      'sequenceDiagram',
      'classDiagram',
      'stateDiagram',
      'erDiagram',
      'gantt',
      'pie',
      'mindmap',
      'subgraph',
      'loop',
      'alt',
      'opt',
      'par',
      'critical',
      'break',
      'rect',
      'state',
      'class',
    ];

    // 定义需要减少缩进的关键字
    final decreaseIndentKeywords = ['end'];

    for (var line in lines) {
      // 移除行首尾空白
      var trimmedLine = line.trim();

      // 跳过空行（但保留一个）
      if (trimmedLine.isEmpty) {
        if (formattedLines.isNotEmpty && formattedLines.last.isNotEmpty) {
          formattedLines.add('');
        }
        continue;
      }

      // 检查是否需要减少缩进（end 等）
      final shouldDecreaseFirst = decreaseIndentKeywords.any(
        (keyword) =>
            trimmedLine.toLowerCase() == keyword ||
            trimmedLine.toLowerCase().startsWith('$keyword '),
      );

      if (shouldDecreaseFirst && indentLevel > 0) {
        indentLevel--;
      }

      // 添加缩进
      final indent = '    ' * indentLevel;
      formattedLines.add('$indent$trimmedLine');

      // 检查是否需要增加缩进
      final shouldIncrease = increaseIndentKeywords.any(
        (keyword) =>
            trimmedLine.toLowerCase().startsWith(keyword) ||
            trimmedLine.toLowerCase().startsWith('$keyword '),
      );

      if (shouldIncrease) {
        indentLevel++;
      }
    }

    // 移除末尾多余空行
    while (formattedLines.isNotEmpty && formattedLines.last.isEmpty) {
      formattedLines.removeLast();
    }

    return formattedLines.join('\n');
  }

  /// 执行格式化
  void _performFormat() {
    final formatted = _formatMermaidCode(controller.text);
    controller.text = formatted;
    // 将光标移到末尾
    controller.selection = TextSelection.collapsed(offset: formatted.length);
    onChanged(formatted);
  }

  /// 构建右键菜单项
  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isEnabled ? Colors.black87 : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isEnabled ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 131, 56, 10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromARGB(255, 197, 140, 105)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.code,
                  size: 18,
                  color: Color.fromARGB(179, 255, 209, 167),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Mermaid 代码',
                    style: TextStyle(
                      color: Color.fromARGB(179, 251, 255, 0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 代码输入区域
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus && onFocusLost != null) {
                  onFocusLost!();
                }
              },
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'Consolas, Monaco, monospace',
                  fontSize: 14,
                  color: Color.fromARGB(255, 228, 202, 168),
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText:
                      '在这里输入 Mermaid 代码...\n\n例如:\ngraph TD\n    A[开始] --> B[结束]',
                  hintStyle: TextStyle(
                    color: Colors.white24,
                    fontFamily: 'Consolas, Monaco, monospace',
                  ),
                ),
                cursorColor: Colors.white70,
                contextMenuBuilder: (context, editableTextState) {
                  final anchors = editableTextState.contextMenuAnchors;
                  return Stack(
                    children: [
                      Positioned(
                        left: anchors.primaryAnchor.dx,
                        top: anchors.primaryAnchor.dy,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                          child: IntrinsicWidth(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 剪切
                                _buildContextMenuItem(
                                  icon: Icons.content_cut,
                                  label: '剪切',
                                  onPressed: editableTextState.cutEnabled
                                      ? () {
                                          editableTextState.cutSelection(
                                            SelectionChangedCause.toolbar,
                                          );
                                        }
                                      : null,
                                ),
                                // 复制
                                _buildContextMenuItem(
                                  icon: Icons.content_copy,
                                  label: '复制',
                                  onPressed: editableTextState.copyEnabled
                                      ? () {
                                          editableTextState.copySelection(
                                            SelectionChangedCause.toolbar,
                                          );
                                        }
                                      : null,
                                ),
                                // 粘贴
                                _buildContextMenuItem(
                                  icon: Icons.content_paste,
                                  label: '粘贴',
                                  onPressed: editableTextState.pasteEnabled
                                      ? () {
                                          editableTextState.pasteText(
                                            SelectionChangedCause.toolbar,
                                          );
                                        }
                                      : null,
                                ),
                                // 分隔线
                                Container(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                ),
                                // 格式化
                                _buildContextMenuItem(
                                  icon: Icons.format_align_left,
                                  label: '格式化',
                                  onPressed: () {
                                    editableTextState.hideToolbar();
                                    _performFormat();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
