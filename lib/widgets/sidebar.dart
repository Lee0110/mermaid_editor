import 'package:flutter/material.dart';
import '../models/mermaid_document.dart';
import '../models/document_group.dart';

class Sidebar extends StatefulWidget {
  final List<DocumentGroup> groups;
  final List<MermaidDocument> documents;
  final MermaidDocument? selectedDocument;
  final Function(MermaidDocument) onDocumentSelected;
  final VoidCallback onCreateGroup;
  final Function(String groupId) onCreateDocument;
  final Function(DocumentGroup) onDeleteGroup;
  final Function(DocumentGroup, String) onRenameGroup;
  final Function(String groupId) onToggleGroup;
  final Function(MermaidDocument) onDeleteDocument;
  final Function(MermaidDocument, String) onRenameDocument;
  final VoidCallback? onOpenSettings;

  const Sidebar({
    super.key,
    required this.groups,
    required this.documents,
    required this.selectedDocument,
    required this.onDocumentSelected,
    required this.onCreateGroup,
    required this.onCreateDocument,
    required this.onDeleteGroup,
    required this.onRenameGroup,
    required this.onToggleGroup,
    required this.onDeleteDocument,
    required this.onRenameDocument,
    this.onOpenSettings,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentGroup> get _filteredGroups {
    if (_searchQuery.isEmpty) {
      return widget.groups;
    }
    // 过滤：组名匹配或者组内有文档匹配
    return widget.groups.where((group) {
      if (group.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return true;
      }
      final docsInGroup = widget.documents.where((doc) => doc.groupId == group.id);
      return docsInGroup.any((doc) => 
        doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        doc.code.toLowerCase().contains(_searchQuery.toLowerCase())
      );
    }).toList();
  }

  List<MermaidDocument> _getDocumentsForGroup(String groupId) {
    var docs = widget.documents.where((doc) => doc.groupId == groupId).toList();
    
    if (_searchQuery.isNotEmpty) {
      docs = docs.where((doc) =>
        doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        doc.code.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // 按创建时间排序
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    final sortedGroups = List<DocumentGroup>.from(_filteredGroups)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      color: const Color.fromARGB(255, 212, 92, 17),
      child: Column(
        children: [
          // 顶部标题和新建按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/32.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Mermaid 编辑器',
                          style: const TextStyle(
                            color: Color.fromARGB(179, 251, 255, 0),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: '新建分组',
                  child: IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined, color: Color.fromARGB(179, 251, 255, 0)),
                    onPressed: widget.onCreateGroup,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                if (widget.onOpenSettings != null)
                  Tooltip(
                    message: '设置',
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color.fromARGB(179, 251, 255, 0)),
                      onPressed: widget.onOpenSettings,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
              ],
            ),
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Color.fromARGB(255, 255, 170, 58), fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF3D332D),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // 分组列表
          Expanded(
            child: sortedGroups.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sortedGroups.length,
                    itemBuilder: (context, index) {
                      final group = sortedGroups[index];
                      final docsInGroup = _getDocumentsForGroup(group.id);
                      return _GroupItem(
                        group: group,
                        documents: docsInGroup,
                        selectedDocument: widget.selectedDocument,
                        searchQuery: _searchQuery,
                        onDocumentSelected: widget.onDocumentSelected,
                        onToggleGroup: () => widget.onToggleGroup(group.id),
                        onRenameGroup: (newName) => widget.onRenameGroup(group, newName),
                        onDeleteGroup: () => widget.onDeleteGroup(group),
                        onCreateDocument: () => widget.onCreateDocument(group.id),
                        onRenameDocument: widget.onRenameDocument,
                        onDeleteDocument: widget.onDeleteDocument,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? '没有找到匹配的内容' : '还没有分组',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onCreateGroup,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建分组'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupItem extends StatefulWidget {
  final DocumentGroup group;
  final List<MermaidDocument> documents;
  final MermaidDocument? selectedDocument;
  final String searchQuery;
  final Function(MermaidDocument) onDocumentSelected;
  final VoidCallback onToggleGroup;
  final Function(String) onRenameGroup;
  final VoidCallback onDeleteGroup;
  final VoidCallback onCreateDocument;
  final Function(MermaidDocument, String) onRenameDocument;
  final Function(MermaidDocument) onDeleteDocument;

  const _GroupItem({
    required this.group,
    required this.documents,
    required this.selectedDocument,
    required this.searchQuery,
    required this.onDocumentSelected,
    required this.onToggleGroup,
    required this.onRenameGroup,
    required this.onDeleteGroup,
    required this.onCreateDocument,
    required this.onRenameDocument,
    required this.onDeleteDocument,
  });

  @override
  State<_GroupItem> createState() => _GroupItemState();
}

class _GroupItemState extends State<_GroupItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.group.name);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.group.name;
    });
  }

  void _finishEditing() {
    final newName = _editController.text.trim();
    if (newName.isNotEmpty && newName != widget.group.name) {
      widget.onRenameGroup(newName);
    }
    setState(() => _isEditing = false);
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D332D),
        title: const Text('删除分组', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除分组 "${widget.group.name}" 吗？\n这将同时删除该分组下的所有图表（${widget.documents.length} 个）。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeleteGroup();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题行
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: InkWell(
            onTap: widget.onToggleGroup,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    widget.group.isExpanded 
                        ? Icons.keyboard_arrow_down 
                        : Icons.keyboard_arrow_right,
                    color: Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    widget.group.isExpanded ? Icons.folder_open : Icons.folder,
                    color: Colors.amber.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isEditing
                        ? TextField(
                            controller: _editController,
                            focusNode: _focusNode,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _finishEditing(),
                          )
                        : Text(
                            widget.group.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  // 操作按钮
                  if (_isHovering && !_isEditing) ...[
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: '重命名',
                      onPressed: _startEditing,
                    ),
                    _buildActionButton(
                      icon: Icons.add,
                      tooltip: '新建图表',
                      onPressed: widget.onCreateDocument,
                    ),
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      tooltip: '删除分组',
                      onPressed: _showDeleteConfirmation,
                      color: Colors.red.shade300,
                    ),
                  ],
                  // 文档数量标签
                  if (!_isHovering && widget.documents.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.documents.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 展开的文档列表
        if (widget.group.isExpanded)
          ...widget.documents.map((doc) => _DocumentItem(
                document: doc,
                isSelected: widget.selectedDocument?.id == doc.id,
                searchQuery: widget.searchQuery,
                onTap: () => widget.onDocumentSelected(doc),
                onRename: (newName) => widget.onRenameDocument(doc, newName),
                onDelete: () => widget.onDeleteDocument(doc),
              )),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: color ?? Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _DocumentItem extends StatefulWidget {
  final MermaidDocument document;
  final bool isSelected;
  final String searchQuery;
  final VoidCallback onTap;
  final Function(String) onRename;
  final VoidCallback onDelete;

  const _DocumentItem({
    required this.document,
    required this.isSelected,
    required this.searchQuery,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_DocumentItem> createState() => _DocumentItemState();
}

class _DocumentItemState extends State<_DocumentItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.document.title);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.document.title;
    });
  }

  void _finishEditing() {
    final newName = _editController.text.trim();
    if (newName.isNotEmpty && newName != widget.document.title) {
      widget.onRename(newName);
    }
    setState(() => _isEditing = false);
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D332D),
        title: const Text('删除图表', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除图表 "${widget.document.title}" 吗？',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: widget.isSelected ? Colors.white : Colors.white70,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index < 0) {
      return Text(
        text,
        style: TextStyle(
          color: widget.isSelected ? Colors.white : Colors.white70,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          color: widget.isSelected ? Colors.white : Colors.white70,
          fontSize: 13,
        ),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(left: 48, right: 12, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : _isHovering
                    ? Colors.white.withValues(alpha: 0.05)
                    : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: widget.isSelected ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isEditing
                    ? TextField(
                        controller: _editController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _finishEditing(),
                      )
                    : _buildHighlightedText(widget.document.title, widget.searchQuery),
              ),
              if (_isHovering && !_isEditing) ...[
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  tooltip: '重命名',
                  onPressed: _startEditing,
                ),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  tooltip: '删除',
                  onPressed: _showDeleteConfirmation,
                  color: Colors.red.shade300,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: color ?? Colors.white54,
          ),
        ),
      ),
    );
  }
}
