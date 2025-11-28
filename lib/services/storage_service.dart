import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/mermaid_document.dart';
import '../models/document_group.dart';
import '../models/app_settings.dart';

/// 存储服务
/// 负责管理文档和设置的持久化存储
class StorageService {
  static StorageService? _instance;
  late String _basePath;
  late AppSettings _settings;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  /// 初始化存储服务
  Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _basePath = p.join(appDocDir.path, 'MermaidEditor');
    
    // 确保基础目录存在
    await Directory(_basePath).create(recursive: true);
    
    // 加载设置
    await _loadSettings();
  }

  /// 获取当前存储路径
  String get storagePath => _settings.storagePath;

  /// 获取当前设置
  AppSettings get settings => _settings;

  /// 加载设置
  Future<void> _loadSettings() async {
    final settingsFile = File(p.join(_basePath, 'settings.json'));
    if (await settingsFile.exists()) {
      try {
        final content = await settingsFile.readAsString();
        _settings = AppSettings.fromJson(jsonDecode(content));
      } catch (e) {
        _settings = AppSettings(storagePath: p.join(_basePath, 'documents'));
      }
    } else {
      _settings = AppSettings(storagePath: p.join(_basePath, 'documents'));
    }
    
    // 确保文档目录存在
    await Directory(_settings.storagePath).create(recursive: true);
  }

  /// 保存设置
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
    final settingsFile = File(p.join(_basePath, 'settings.json'));
    await settingsFile.writeAsString(jsonEncode(settings.toJson()));
    
    // 确保新的存储路径存在
    await Directory(settings.storagePath).create(recursive: true);
  }

  /// 更新存储路径
  Future<void> updateStoragePath(String newPath) async {
    final newSettings = _settings.copyWith(storagePath: newPath);
    await saveSettings(newSettings);
  }

  // ==================== 分组相关 ====================

  /// 获取所有分组
  Future<List<DocumentGroup>> getAllGroups() async {
    final groupsFile = File(p.join(_settings.storagePath, 'groups.json'));
    if (await groupsFile.exists()) {
      try {
        final content = await groupsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((json) => DocumentGroup.fromJson(json))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// 保存所有分组
  Future<void> _saveAllGroups(List<DocumentGroup> groups) async {
    final groupsFile = File(p.join(_settings.storagePath, 'groups.json'));
    final jsonList = groups.map((g) => g.toJson()).toList();
    await groupsFile.writeAsString(jsonEncode(jsonList));
  }

  /// 保存单个分组
  Future<void> saveGroup(DocumentGroup group) async {
    final groups = await getAllGroups();
    final index = groups.indexWhere((g) => g.id == group.id);
    if (index >= 0) {
      groups[index] = group;
    } else {
      groups.insert(0, group);
    }
    await _saveAllGroups(groups);
  }

  /// 删除分组（同时删除分组下的所有文档）
  Future<void> deleteGroup(String groupId) async {
    // 删除分组下的所有文档
    final documents = await getAllDocuments();
    documents.removeWhere((doc) => doc.groupId == groupId);
    await _saveAllDocuments(documents);
    
    // 删除分组
    final groups = await getAllGroups();
    groups.removeWhere((g) => g.id == groupId);
    await _saveAllGroups(groups);
  }

  // ==================== 文档相关 ====================

  /// 获取所有文档
  Future<List<MermaidDocument>> getAllDocuments() async {
    final documentsFile = File(p.join(_settings.storagePath, 'documents.json'));
    if (await documentsFile.exists()) {
      try {
        final content = await documentsFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((json) => MermaidDocument.fromJson(json))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// 获取分组下的文档
  Future<List<MermaidDocument>> getDocumentsByGroup(String groupId) async {
    final documents = await getAllDocuments();
    return documents.where((doc) => doc.groupId == groupId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 保存所有文档
  Future<void> _saveAllDocuments(List<MermaidDocument> documents) async {
    final documentsFile = File(p.join(_settings.storagePath, 'documents.json'));
    final jsonList = documents.map((doc) => doc.toJson()).toList();
    await documentsFile.writeAsString(jsonEncode(jsonList));
  }

  /// 保存单个文档
  Future<void> saveDocument(MermaidDocument document) async {
    final documents = await getAllDocuments();
    final index = documents.indexWhere((doc) => doc.id == document.id);
    if (index >= 0) {
      documents[index] = document;
    } else {
      documents.insert(0, document);
    }
    await _saveAllDocuments(documents);
  }

  /// 删除文档
  Future<void> deleteDocument(String id) async {
    final documents = await getAllDocuments();
    documents.removeWhere((doc) => doc.id == id);
    await _saveAllDocuments(documents);
  }

  /// 获取单个文档
  Future<MermaidDocument?> getDocument(String id) async {
    final documents = await getAllDocuments();
    try {
      return documents.firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }
}
