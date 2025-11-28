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
              border: Border(
                bottom: BorderSide(color: Colors.white12),
              ),
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
                  hintText: '在这里输入 Mermaid 代码...\n\n例如:\ngraph TD\n    A[开始] --> B[结束]',
                  hintStyle: TextStyle(
                    color: Colors.white24,
                    fontFamily: 'Consolas, Monaco, monospace',
                  ),
                ),
                cursorColor: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
