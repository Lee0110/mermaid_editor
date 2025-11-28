import 'package:uuid/uuid.dart';

/// 文档分组模型
class DocumentGroup {
  final String id;
  final String name;
  final DateTime createdAt;
  final bool isExpanded;

  const DocumentGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isExpanded = true,
  });

  /// 创建新分组
  factory DocumentGroup.create({String name = '新分组'}) {
    return DocumentGroup(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      isExpanded: true,
    );
  }

  /// 从 JSON 创建
  factory DocumentGroup.fromJson(Map<String, dynamic> json) {
    return DocumentGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isExpanded: json['isExpanded'] as bool? ?? true,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isExpanded': isExpanded,
    };
  }

  /// 复制并修改
  DocumentGroup copyWith({
    String? name,
    bool? isExpanded,
  }) {
    return DocumentGroup(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
