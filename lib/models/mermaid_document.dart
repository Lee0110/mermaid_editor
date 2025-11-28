import 'package:uuid/uuid.dart';

/// Mermaid 文档模型
/// 用于存储单个 Mermaid 代码片段的信息
class MermaidDocument {
  final String id;
  final String? groupId; // 所属分组ID
  String title;
  String code;
  final DateTime createdAt;
  DateTime updatedAt;

  MermaidDocument({
    String? id,
    this.groupId,
    required this.title,
    required this.code,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从 JSON 创建文档
  factory MermaidDocument.fromJson(Map<String, dynamic> json) {
    return MermaidDocument(
      id: json['id'] as String,
      groupId: json['groupId'] as String?,
      title: json['title'] as String,
      code: json['code'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'code': code,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 创建新文档的默认模板
  factory MermaidDocument.create({String? title, String? groupId}) {
    return MermaidDocument(
      groupId: groupId,
      title: title ?? '未命名图表',
      code: '''graph TD
    A[开始] --> B{判断}
    B -->|是| C[执行操作]
    B -->|否| D[结束]
    C --> D''',
    );
  }

  /// 复制并更新
  MermaidDocument copyWith({
    String? title,
    String? code,
    String? groupId,
  }) {
    return MermaidDocument(
      id: id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      code: code ?? this.code,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
