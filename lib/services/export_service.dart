import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// 导出服务
/// 负责将 Mermaid 图表导出为图片
class ExportService {
  /// 导出 PNG 图片
  static Future<bool> exportPng(String base64Data, String defaultFileName) async {
    try {
      // 移除 base64 前缀
      final base64String = base64Data.replaceFirst(RegExp(r'data:image/png;base64,'), '');
      final bytes = base64Decode(base64String);
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存 PNG 图片',
        fileName: '$defaultFileName.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(bytes);
        return true;
      }
      return false;
    } catch (e) {
      print('导出 PNG 失败: $e');
      return false;
    }
  }

  /// 导出 SVG 图片
  static Future<bool> exportSvg(String svgContent, String defaultFileName) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存 SVG 图片',
        fileName: '$defaultFileName.svg',
        type: FileType.custom,
        allowedExtensions: ['svg'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsString(svgContent);
        return true;
      }
      return false;
    } catch (e) {
      print('导出 SVG 失败: $e');
      return false;
    }
  }
}
