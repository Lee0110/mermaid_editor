import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 导出尺寸选项
enum ExportSizeMode {
  original, // 原始尺寸
  scale,    // 按倍数缩放
  custom,   // 自定义尺寸
}

/// 导出设置结果
class ExportSettings {
  final ExportSizeMode mode;
  final double scale;
  final int? customWidth;
  final int? customHeight;
  final bool keepAspectRatio;

  const ExportSettings({
    required this.mode,
    this.scale = 1.0,
    this.customWidth,
    this.customHeight,
    this.keepAspectRatio = true,
  });

  /// 计算导出尺寸
  /// [originalWidth] 和 [originalHeight] 是原始 SVG 的尺寸
  (int width, int height) calculateSize(int originalWidth, int originalHeight) {
    switch (mode) {
      case ExportSizeMode.original:
        return (originalWidth, originalHeight);
      case ExportSizeMode.scale:
        return (
          (originalWidth * scale).round(),
          (originalHeight * scale).round(),
        );
      case ExportSizeMode.custom:
        if (keepAspectRatio) {
          if (customWidth != null) {
            final ratio = customWidth! / originalWidth;
            return (customWidth!, (originalHeight * ratio).round());
          } else if (customHeight != null) {
            final ratio = customHeight! / originalHeight;
            return ((originalWidth * ratio).round(), customHeight!);
          }
        }
        return (
          customWidth ?? originalWidth,
          customHeight ?? originalHeight,
        );
    }
  }
}

/// 导出设置对话框
class ExportDialog extends StatefulWidget {
  final String exportType; // 'PNG' 或 'SVG'
  final int originalWidth;
  final int originalHeight;

  const ExportDialog({
    super.key,
    required this.exportType,
    required this.originalWidth,
    required this.originalHeight,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportSizeMode _mode = ExportSizeMode.scale;
  double _scale = 2.0; // 默认 2 倍
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  bool _keepAspectRatio = true;
  
  // 防止循环更新的标志
  bool _isUpdating = false;

  // 预设倍数选项
  final List<double> _scaleOptions = [1.0, 2.0, 3.0, 4.0, 5.0, 8.0, 10.0];

  @override
  void initState() {
    super.initState();
    _widthController.text = (widget.originalWidth * 2).toString();
    _heightController.text = (widget.originalHeight * 2).toString();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateHeightFromWidth() {
    if (_isUpdating || !_keepAspectRatio) return;
    if (_widthController.text.isNotEmpty) {
      final width = int.tryParse(_widthController.text);
      if (width != null && widget.originalWidth > 0) {
        _isUpdating = true;
        final ratio = width / widget.originalWidth;
        _heightController.text = (widget.originalHeight * ratio).round().toString();
        _isUpdating = false;
      }
    }
  }

  void _updateWidthFromHeight() {
    if (_isUpdating || !_keepAspectRatio) return;
    if (_heightController.text.isNotEmpty) {
      final height = int.tryParse(_heightController.text);
      if (height != null && widget.originalHeight > 0) {
        _isUpdating = true;
        final ratio = height / widget.originalHeight;
        _widthController.text = (widget.originalWidth * ratio).round().toString();
        _isUpdating = false;
      }
    }
  }

  int get _previewWidth {
    switch (_mode) {
      case ExportSizeMode.original:
        return widget.originalWidth;
      case ExportSizeMode.scale:
        return (widget.originalWidth * _scale).round();
      case ExportSizeMode.custom:
        return int.tryParse(_widthController.text) ?? widget.originalWidth;
    }
  }

  int get _previewHeight {
    switch (_mode) {
      case ExportSizeMode.original:
        return widget.originalHeight;
      case ExportSizeMode.scale:
        return (widget.originalHeight * _scale).round();
      case ExportSizeMode.custom:
        return int.tryParse(_heightController.text) ?? widget.originalHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.exportType == 'PNG' ? Icons.image : Icons.code,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text('导出 ${widget.exportType}'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 原始尺寸信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '原始尺寸: ${widget.originalWidth} × ${widget.originalHeight} px',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 尺寸模式选择
            const Text('导出尺寸', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 原始尺寸
            _buildRadioOption(
              ExportSizeMode.original,
              '原始尺寸',
              '按图表原始大小导出',
            ),

            // 按倍数缩放
            _buildRadioOption(
              ExportSizeMode.scale,
              '按倍数缩放',
              null,
            ),
            if (_mode == ExportSizeMode.scale)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 8, bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _scaleOptions.map((scale) {
                    final isSelected = _scale == scale;
                    return ChoiceChip(
                      label: Text('${scale.toInt()}x'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _scale = scale);
                        }
                      },
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    );
                  }).toList(),
                ),
              ),

            // 自定义尺寸
            _buildRadioOption(
              ExportSizeMode.custom,
              '自定义尺寸',
              null,
            ),
            if (_mode == ExportSizeMode.custom)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            decoration: const InputDecoration(
                              labelText: '宽度',
                              suffixText: 'px',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) {
                              _updateHeightFromWidth();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            _keepAspectRatio ? Icons.link : Icons.link_off,
                            color: _keepAspectRatio
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _keepAspectRatio = !_keepAspectRatio;
                            });
                          },
                          tooltip: _keepAspectRatio ? '保持比例' : '自由比例',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: '高度',
                              suffixText: 'px',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) {
                              _updateWidthFromHeight();
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 预览尺寸
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.preview, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '导出尺寸: $_previewWidth × $_previewHeight px',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final settings = ExportSettings(
              mode: _mode,
              scale: _scale,
              customWidth: int.tryParse(_widthController.text),
              customHeight: int.tryParse(_heightController.text),
              keepAspectRatio: _keepAspectRatio,
            );
            Navigator.pop(context, settings);
          },
          icon: const Icon(Icons.download),
          label: const Text('导出'),
        ),
      ],
    );
  }

  Widget _buildRadioOption(ExportSizeMode mode, String title, String? subtitle) {
    return RadioListTile<ExportSizeMode>(
      value: mode,
      groupValue: _mode,
      onChanged: (value) {
        setState(() => _mode = value!);
      },
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
