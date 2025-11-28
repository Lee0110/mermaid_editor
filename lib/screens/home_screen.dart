import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mermaid_document.dart';
import '../models/document_group.dart';
import '../services/storage_service.dart';
import '../services/export_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/code_editor.dart';
import '../widgets/mermaid_preview.dart';
import 'settings_dialog.dart';

/// 主页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<MermaidDocument> _documents = [];
  List<DocumentGroup> _groups = [];
  MermaidDocument? _currentDocument;
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<MermaidPreviewState> _previewKey = GlobalKey();
  bool _isLoading = true;
  
  // 全屏相关
  bool _isFullscreen = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // 可调整宽度相关
  double _sidebarWidth = 260.0;
  double _editorWidthRatio = 0.5; // 编辑器占主内容区的比例
  
  static const double _minSidebarWidth = 180.0;
  static const double _maxSidebarWidth = 400.0;
  static const double _minEditorRatio = 0.2;
  static const double _maxEditorRatio = 0.8;

  @override
  void initState() {
    super.initState();
    _initApp();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // 监听全局键盘事件
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animationController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }
  
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _exitFullscreen();
        return true;
      }
    }
    return false;
  }

  Future<void> _initApp() async {
    await StorageService.instance.init();
    await _loadDocuments();
    setState(() => _isLoading = false);
  }

  Future<void> _loadDocuments() async {
    final docs = await StorageService.instance.getAllDocuments();
    final groups = await StorageService.instance.getAllGroups();
    setState(() {
      _documents = docs;
      _groups = groups;
      if (docs.isNotEmpty && _currentDocument == null) {
        _selectDocument(docs.first);
      }
    });
  }

  void _selectDocument(MermaidDocument doc) {
    // 先保存当前文档
    _saveCurrentDocument();
    
    setState(() {
      _currentDocument = doc;
      _codeController.text = doc.code;
    });
  }

  Future<void> _createNewDocument(String groupId) async {
    // 先保存当前文档
    await _saveCurrentDocument();
    
    final newDoc = MermaidDocument.create(groupId: groupId);
    await StorageService.instance.saveDocument(newDoc);
    
    setState(() {
      _documents.insert(0, newDoc);
      _currentDocument = newDoc;
      _codeController.text = newDoc.code;
    });
  }

  Future<void> _deleteDocument(MermaidDocument doc) async {
    await StorageService.instance.deleteDocument(doc.id);
    
    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
      if (_currentDocument?.id == doc.id) {
        if (_documents.isNotEmpty) {
          _selectDocument(_documents.first);
        } else {
          _currentDocument = null;
          _codeController.clear();
        }
      }
    });
  }

  Future<void> _renameDocument(MermaidDocument doc, String newTitle) async {
    final index = _documents.indexWhere((d) => d.id == doc.id);
    if (index >= 0) {
      final updatedDoc = _documents[index].copyWith(title: newTitle);
      await StorageService.instance.saveDocument(updatedDoc);
      
      setState(() {
        _documents[index] = updatedDoc;
        if (_currentDocument?.id == doc.id) {
          _currentDocument = updatedDoc;
        }
      });
    }
  }

  // 分组相关方法
  Future<void> _createGroup() async {
    final newGroup = DocumentGroup.create(name: '新建分组');
    await StorageService.instance.saveGroup(newGroup);
    
    setState(() {
      _groups.insert(0, newGroup);
    });
  }

  Future<void> _deleteGroup(DocumentGroup group) async {
    await StorageService.instance.deleteGroup(group.id);
    
    setState(() {
      _groups.removeWhere((g) => g.id == group.id);
      // 删除该分组下的所有文档
      _documents.removeWhere((doc) => doc.groupId == group.id);
      
      // 如果当前文档属于被删除的分组，清空选择
      if (_currentDocument?.groupId == group.id) {
        if (_documents.isNotEmpty) {
          _selectDocument(_documents.first);
        } else {
          _currentDocument = null;
          _codeController.clear();
        }
      }
    });
  }

  Future<void> _renameGroup(DocumentGroup group, String newName) async {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index >= 0) {
      final updatedGroup = group.copyWith(name: newName);
      await StorageService.instance.saveGroup(updatedGroup);
      
      setState(() {
        _groups[index] = updatedGroup;
      });
    }
  }

  void _toggleGroup(String groupId) {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index >= 0) {
      setState(() {
        final group = _groups[index];
        _groups[index] = group.copyWith(isExpanded: !group.isExpanded);
      });
      // 保存展开状态
      StorageService.instance.saveGroup(_groups[index]);
    }
  }

  void _onCodeChanged(String code) {
    if (_currentDocument != null) {
      setState(() {
        _currentDocument = _currentDocument!.copyWith(code: code);
      });
    }
  }

  Future<void> _saveCurrentDocument() async {
    if (_currentDocument != null) {
      final updatedDoc = _currentDocument!.copyWith(code: _codeController.text);
      await StorageService.instance.saveDocument(updatedDoc);
      
      // 更新列表中的文档
      final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
      if (index >= 0) {
        setState(() {
          _documents[index] = updatedDoc;
        });
      }
    }
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    _animationController.forward();
  }
  
  void _exitFullscreen() {
    _animationController.reverse().then((_) {
      setState(() => _isFullscreen = false);
    });
  }

  /// 获取当前分组内的文档列表（按创建时间排序）
  List<MermaidDocument> _getDocumentsInCurrentGroup() {
    if (_currentDocument == null) return [];
    final groupId = _currentDocument!.groupId;
    final docs = _documents.where((doc) => doc.groupId == groupId).toList();
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  /// 获取上一个文档（同分组内）
  MermaidDocument? _getPrevDocument() {
    final docs = _getDocumentsInCurrentGroup();
    if (docs.isEmpty || _currentDocument == null) return null;
    final currentIndex = docs.indexWhere((d) => d.id == _currentDocument!.id);
    if (currentIndex <= 0) return null;
    return docs[currentIndex - 1];
  }

  /// 获取下一个文档（同分组内）
  MermaidDocument? _getNextDocument() {
    final docs = _getDocumentsInCurrentGroup();
    if (docs.isEmpty || _currentDocument == null) return null;
    final currentIndex = docs.indexWhere((d) => d.id == _currentDocument!.id);
    if (currentIndex < 0 || currentIndex >= docs.length - 1) return null;
    return docs[currentIndex + 1];
  }

  /// 跳转到上一个文档
  void _goToPrevDocument() {
    final prevDoc = _getPrevDocument();
    if (prevDoc != null) {
      _selectDocument(prevDoc);
      // 重置缩放
      _previewKey.currentState?.resetZoom();
    }
  }

  /// 跳转到下一个文档
  void _goToNextDocument() {
    final nextDoc = _getNextDocument();
    if (nextDoc != null) {
      _selectDocument(nextDoc);
      // 重置缩放
      _previewKey.currentState?.resetZoom();
    }
  }

  Future<void> _exportPng(String base64Data, int width, int height) async {
    final fileName = _currentDocument?.title ?? 'mermaid';
    final success = await ExportService.exportPng(base64Data, fileName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'PNG 导出成功！($width × $height px)' 
            : '导出失败，请重试'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _exportSvg(String svgContent) async {
    final fileName = _currentDocument?.title ?? 'mermaid';
    final success = await ExportService.exportSvg(svgContent, fileName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'SVG 导出成功！' : '导出失败，请重试'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// 创建示例分组
  Future<void> _createExampleGroup() async {
    // 创建示例分组
    final exampleGroup = DocumentGroup.create(name: '示例分组');
    await StorageService.instance.saveGroup(exampleGroup);

    // 示例图表列表
    final examples = [
      {
        'title': '流程图示例',
        'code': '''graph TD
    A[开始] --> B{是否登录?}
    B -->|是| C[进入主页]
    C --> D[浏览内容]
    D --> E{是否退出?}
    E -->|是| F[结束]
    E -->|否| D
    B -->|否| G[跳转登录页]
    G --> B'''
      },
      {
        'title': '时序图示例',
        'code': '''sequenceDiagram
    participant 用户
    participant 前端
    participant 后端
    participant 数据库

    用户->>+前端: 点击登录
    前端->>+后端: 发送登录请求
    后端->>+数据库: 查询用户信息
    数据库-->>-后端: 返回用户数据
    后端-->>-前端: 返回登录结果
    前端-->>-用户: 显示登录成功'''
      },
      {
        'title': '类图示例',
        'code': '''classDiagram
    class Animal {
        +String name
        +int age
        +makeSound()
    }
    class Dog {
        +String breed
        +bark()
        +fetch()
    }
    class Cat {
        +String color
        +meow()
        +scratch()
    }
    Animal <|-- Dog
    Animal <|-- Cat'''
      },
      {
        'title': '状态图示例',
        'code': '''stateDiagram-v2
    [*] --> 待机
    待机 --> 处理中 : 收到请求
    处理中 --> 成功 : 处理完成
    处理中 --> 失败 : 发生错误
    成功 --> 待机 : 重置
    失败 --> 待机 : 重试
    成功 --> [*]
    失败 --> [*]'''
      },
      {
        'title': '甘特图示例',
        'code': '''gantt
    title 项目开发计划
    dateFormat  YYYY-MM-DD
    section 需求分析
    需求调研           :a1, 2024-01-01, 7d
    需求文档           :after a1, 5d
    section 设计阶段
    概要设计           :2024-01-13, 7d
    详细设计           :2024-01-20, 10d
    section 开发阶段
    前端开发           :2024-01-30, 20d
    后端开发           :2024-01-30, 25d
    section 测试阶段
    单元测试           :2024-02-24, 7d
    集成测试           :2024-03-02, 7d'''
      },
      {
        'title': '饼图示例',
        'code': '''pie showData
    title 浏览器市场份额
    "Chrome" : 65
    "Safari" : 19
    "Firefox" : 8
    "Edge" : 5
    "其他" : 3'''
      },
      {
        'title': '思维导图示例',
        'code': '''mindmap
  root((知识管理))
    收集
      网页剪藏
      笔记应用
      书籍摘录
    整理
      分类标签
      思维导图
      关键词
    分享
      博客文章
      社交媒体
      团队协作'''
      },
      {
        'title': 'ER图示例',
        'code': '''erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    CUSTOMER {
        string name
        string email
        string address
    }
    ORDER {
        int orderNumber
        date orderDate
        string status
    }
    LINE_ITEM {
        int quantity
        float price
        string productName
    }'''
      },
      {
        'title': '旅程图示例',
        'code': '''journey
    title 用户购物体验
    section 浏览商品
      打开网站: 5: 用户
      搜索商品: 4: 用户
      查看详情: 4: 用户
    section 下单支付
      加入购物车: 5: 用户
      填写地址: 3: 用户
      支付订单: 4: 用户
    section 等待收货
      查看物流: 3: 用户
      收到包裹: 5: 用户'''
      },
    ];

    // 创建示例文档
    final newDocs = <MermaidDocument>[];
    for (final example in examples) {
      final doc = MermaidDocument(
        groupId: exampleGroup.id,
        title: example['title']!,
        code: example['code']!,
      );
      await StorageService.instance.saveDocument(doc);
      newDocs.add(doc);
    }

    // 更新状态
    setState(() {
      _groups.insert(0, exampleGroup);
      _documents.insertAll(0, newDocs);
    });

    // 显示成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('已创建示例分组，包含 ${examples.length} 个图表示例'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        onCreateExampleGroup: _createExampleGroup,
      ),
    ).then((result) {
      if (result == true) {
        _loadDocuments();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final animatedSidebarWidth = _sidebarWidth * (1 - _animation.value);
          final editorFlex = 1.0 - _animation.value;
          
          return Row(
            children: [
              // 侧边栏（动画隐藏）
              if (animatedSidebarWidth > 0)
                SizedBox(
                  width: animatedSidebarWidth,
                  child: ClipRect(
                    child: Sidebar(
                      groups: _groups,
                      documents: _documents,
                      selectedDocument: _currentDocument,
                      onDocumentSelected: _selectDocument,
                      onCreateGroup: _createGroup,
                      onCreateDocument: _createNewDocument,
                      onDeleteGroup: _deleteGroup,
                      onRenameGroup: _renameGroup,
                      onToggleGroup: _toggleGroup,
                      onDeleteDocument: _deleteDocument,
                      onRenameDocument: _renameDocument,
                      onOpenSettings: _openSettings,
                    ),
                  ),
                ),
              
              // 侧边栏拖动条
              if (animatedSidebarWidth > 0)
                _buildDragHandle(
                  onDrag: (delta) {
                    setState(() {
                      _sidebarWidth = (_sidebarWidth + delta).clamp(
                        _minSidebarWidth,
                        _maxSidebarWidth,
                      );
                    });
                  },
                ),
              
              // 主内容区
              Expanded(
                child: _currentDocument == null
                    ? _buildEmptyState()
                    : _buildEditorArea(editorFlex),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// 构建可拖动的分隔条
  Widget _buildDragHandle({required Function(double) onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          onDrag(details.delta.dx);
        },
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 50),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              '欢迎使用 Mermaid Editor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            // const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorArea(double editorFlex) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final editorWidth = availableWidth * _editorWidthRatio * editorFlex;
          final showEditor = editorFlex > 0.01 && editorWidth > 50;
          
          return Row(
            children: [
              // 代码编辑器（动画隐藏）
              if (showEditor)
                SizedBox(
                  width: editorWidth,
                  child: Opacity(
                    opacity: editorFlex.clamp(0.0, 1.0),
                    child: CodeEditor(
                      controller: _codeController,
                      onChanged: _onCodeChanged,
                      onFocusLost: _saveCurrentDocument,
                    ),
                  ),
                ),
              
              // 编辑器和预览区之间的拖动条
              if (showEditor)
                _buildDragHandle(
                  onDrag: (delta) {
                    setState(() {
                      final newRatio = _editorWidthRatio + delta / availableWidth;
                      _editorWidthRatio = newRatio.clamp(_minEditorRatio, _maxEditorRatio);
                    });
                  },
                ),
              
              // 预览区域
              Expanded(
                child: MermaidPreview(
                  key: _previewKey,
                  code: _codeController.text,
                  title: _currentDocument?.title,
                  onExportPng: _exportPng,
                  onExportSvg: _exportSvg,
                  isFullscreen: _isFullscreen,
                  onToggleFullscreen: () {
                    if (_isFullscreen) {
                      _exitFullscreen();
                    } else {
                      _enterFullscreen();
                    }
                  },
                  onEscPressed: _exitFullscreen,
                  prevDocTitle: _getPrevDocument()?.title,
                  nextDocTitle: _getNextDocument()?.title,
                  onGoPrev: _goToPrevDocument,
                  onGoNext: _goToNextDocument,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
