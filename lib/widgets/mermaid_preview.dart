import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'export_dialog.dart';

/// Mermaid 预览组件
/// 使用 WebView 渲染 Mermaid 图表
class MermaidPreview extends StatefulWidget {
  final String code;
  final String? title; // 图表标题
  final Function(String, int, int) onExportPng; // 增加宽高参数
  final Function(String) onExportSvg;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onEscPressed; // ESC 键回调

  // 全屏导航相关
  final String? prevDocTitle; // 上一个文档标题，null表示没有上一个
  final String? nextDocTitle; // 下一个文档标题，null表示没有下一个
  final VoidCallback? onGoPrev; // 跳转上一个
  final VoidCallback? onGoNext; // 跳转下一个

  const MermaidPreview({
    super.key,
    required this.code,
    this.title,
    required this.onExportPng,
    required this.onExportSvg,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onEscPressed,
    this.prevDocTitle,
    this.nextDocTitle,
    this.onGoPrev,
    this.onGoNext,
  });

  @override
  State<MermaidPreview> createState() => MermaidPreviewState();
}

class MermaidPreviewState extends State<MermaidPreview> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  int _zoomLevel = 100;

  // 缩放比例编辑状态
  bool _isEditingZoom = false;
  final TextEditingController _zoomController = TextEditingController();
  final FocusNode _zoomFocusNode = FocusNode();

  // SVG 原始尺寸
  int _svgWidth = 0;
  int _svgHeight = 0;

  // 待处理的导出设置
  ExportSettings? _pendingExportSettings;

  @override
  void didUpdateWidget(MermaidPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _updateMermaid();
    }
  }

  void _updateMermaid() {
    if (_webViewController != null) {
      final escapedCode = _escapeForJs(widget.code);
      _webViewController!.evaluateJavascript(
        source: 'renderMermaid(`$escapedCode`)',
      );
    }
  }

  String _escapeForJs(String code) {
    return code
        .replaceAll('\\', '\\\\')
        .replaceAll('`', '\\`')
        .replaceAll('\$', '\\\$');
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 100).clamp(10, 1000);
    });
    _webViewController?.evaluateJavascript(source: 'setZoom($_zoomLevel)');
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 100).clamp(10, 1000);
    });
    _webViewController?.evaluateJavascript(source: 'setZoom($_zoomLevel)');
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 100;
    });
    _webViewController?.evaluateJavascript(source: 'resetZoom()');
  }

  /// 公开的重置缩放方法，供外部调用
  void resetZoom() {
    _resetZoom();
  }

  /// 开始编辑缩放比例
  void _startEditingZoom() {
    setState(() {
      _isEditingZoom = true;
      _zoomController.text = '$_zoomLevel';
    });
    // 延迟一下再聚焦并选中全部文字
    Future.delayed(const Duration(milliseconds: 50), () {
      _zoomFocusNode.requestFocus();
      _zoomController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _zoomController.text.length,
      );
    });
  }

  /// 完成编辑缩放比例
  void _finishEditingZoom() {
    final zoom = int.tryParse(_zoomController.text);
    if (zoom != null && mounted) {
      setState(() {
        _zoomLevel = zoom.clamp(10, 1000);
        _isEditingZoom = false;
      });
      _webViewController?.evaluateJavascript(source: 'setZoom($_zoomLevel)');
    } else {
      setState(() {
        _isEditingZoom = false;
      });
    }
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _zoomFocusNode.dispose();
    super.dispose();
  }

  void _exportPng() async {
    // 先获取 SVG 尺寸
    _webViewController?.evaluateJavascript(source: 'getSvgSize()');
  }

  void _showExportDialog() async {
    if (_svgWidth <= 0 || _svgHeight <= 0) {
      // 如果没有有效尺寸，使用默认值
      _svgWidth = 800;
      _svgHeight = 600;
    }

    final settings = await showDialog<ExportSettings>(
      context: context,
      builder: (context) => ExportDialog(
        exportType: 'PNG',
        originalWidth: _svgWidth,
        originalHeight: _svgHeight,
      ),
    );

    if (settings != null) {
      _pendingExportSettings = settings;
      final (width, height) = settings.calculateSize(_svgWidth, _svgHeight);
      // 调用 JS 导出指定尺寸的 PNG
      _webViewController?.evaluateJavascript(
        source: 'triggerExportPngWithSize($width, $height)',
      );
    }
  }

  void _exportSvg() {
    _webViewController?.evaluateJavascript(source: 'triggerExportSvg()');
  }

  void _setupJavaScriptHandlers(InAppWebViewController controller) {
    // 处理缩放变化
    controller.addJavaScriptHandler(
      handlerName: 'onZoomChange',
      callback: (args) {
        if (args.isNotEmpty) {
          final zoom = args[0] as int?;
          if (zoom != null && mounted) {
            setState(() {
              _zoomLevel = zoom.clamp(10, 1000);
            });
          }
        }
      },
    );

    // 处理 SVG 尺寸获取
    controller.addJavaScriptHandler(
      handlerName: 'onSvgSize',
      callback: (args) {
        if (args.length >= 2 && mounted) {
          _svgWidth = (args[0] as num?)?.toInt() ?? 0;
          _svgHeight = (args[1] as num?)?.toInt() ?? 0;
          // 收到尺寸后显示导出对话框
          _showExportDialog();
        }
      },
    );

    // 处理 PNG 导出（带尺寸信息）
    controller.addJavaScriptHandler(
      handlerName: 'onExportPng',
      callback: (args) {
        if (args.isNotEmpty) {
          final data = args[0] as String?;
          final width = args.length > 1 ? (args[1] as num?)?.toInt() ?? 0 : 0;
          final height = args.length > 2 ? (args[2] as num?)?.toInt() ?? 0 : 0;
          if (data != null && data.isNotEmpty) {
            widget.onExportPng(data, width, height);
          }
        }
      },
    );

    // 处理 SVG 导出
    controller.addJavaScriptHandler(
      handlerName: 'onExportSvg',
      callback: (args) {
        if (args.isNotEmpty) {
          final data = args[0] as String?;
          if (data != null && data.isNotEmpty) {
            widget.onExportSvg(data);
          }
        }
      },
    );

    // 处理 ESC 键
    controller.addJavaScriptHandler(
      handlerName: 'onEscPressed',
      callback: (args) {
        if (widget.isFullscreen && widget.onEscPressed != null) {
          widget.onEscPressed!();
        }
      },
    );

    // 处理 Mermaid 渲染结果
    controller.addJavaScriptHandler(
      handlerName: 'onMermaidResult',
      callback: (args) {
        if (args.isNotEmpty && mounted) {
          final success = args[0] as bool? ?? false;
          final errorMsg = args.length > 1 ? args[1] as String? : null;
          setState(() {
            _errorMessage = success ? null : (errorMsg ?? '渲染失败');
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // 工具栏
          _buildToolbar(),

          // 预览区域
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              child: Stack(
                children: [
                  InAppWebView(
                    initialData: InAppWebViewInitialData(
                      data: _getHtmlContent(),
                      mimeType: 'text/html',
                      encoding: 'utf-8',
                    ),
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: true,
                      disableContextMenu: true,
                      supportZoom: false,
                    ),
                    // 彻底禁用右键菜单
                    contextMenu: ContextMenu(
                      settings: ContextMenuSettings(
                        hideDefaultSystemContextMenuItems: true,
                      ),
                      menuItems: [],
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      _setupJavaScriptHandlers(controller);
                    },
                    onLoadStop: (controller, url) {
                      setState(() => _isLoading = false);
                      _updateMermaid();
                    },
                  ),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (_errorMessage != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: widget.isFullscreen ? 70 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.red.shade50,
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 全屏模式下的底部导航栏
                  if (widget.isFullscreen)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildFullscreenNavBar(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.preview, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.title ?? '预览',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),

          // 缩放控制
          _ToolbarIconButton(
            icon: Icons.remove,
            onPressed: _zoomOut,
            tooltip: '缩小',
          ),
          _isEditingZoom
              ? Container(
                  width: 50,
                  height: 24,
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _zoomController,
                    focusNode: _zoomFocusNode,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _finishEditingZoom(),
                    onEditingComplete: _finishEditingZoom,
                    onTapOutside: (_) => _finishEditingZoom(),
                  ),
                )
              : GestureDetector(
                  onDoubleTap: _startEditingZoom,
                  child: Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Tooltip(
                      message: '双击编辑',
                      child: Text(
                        '$_zoomLevel%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
          _ToolbarIconButton(
            icon: Icons.add,
            onPressed: _zoomIn,
            tooltip: '放大',
          ),
          _ToolbarIconButton(
            icon: Icons.refresh,
            onPressed: _resetZoom,
            tooltip: '重置缩放',
          ),

          const SizedBox(width: 8),
          Container(height: 20, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 8),

          // 导出按钮
          _ToolbarButton(
            icon: Icons.image_outlined,
            label: 'PNG',
            onPressed: _exportPng,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(icon: Icons.code, label: 'SVG', onPressed: _exportSvg),
          const SizedBox(width: 8),

          // 全屏按钮
          _ToolbarButton(
            icon: widget.isFullscreen
                ? Icons.fullscreen_exit
                : Icons.fullscreen,
            label: widget.isFullscreen ? '退出' : '全屏',
            onPressed: widget.onToggleFullscreen,
          ),
        ],
      ),
    );
  }

  /// 构建全屏模式下的底部导航栏
  Widget _buildFullscreenNavBar() {
    final hasPrev = widget.prevDocTitle != null;
    final hasNext = widget.nextDocTitle != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上一个按钮
          Expanded(
            child: _FullscreenNavButton(
              icon: Icons.arrow_back,
              label: hasPrev ? '上一个：${widget.prevDocTitle}' : '已是第一个',
              enabled: hasPrev,
              onPressed: hasPrev ? widget.onGoPrev : null,
              alignment: Alignment.centerLeft,
            ),
          ),

          // 中间的退出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onToggleFullscreen,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen_exit,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '退出全屏',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 下一个按钮
          Expanded(
            child: _FullscreenNavButton(
              icon: Icons.arrow_forward,
              label: hasNext ? '下一个：${widget.nextDocTitle}' : '已是最后一个',
              enabled: hasNext,
              onPressed: hasNext ? widget.onGoNext : null,
              alignment: Alignment.centerRight,
              iconOnRight: true,
            ),
          ),
        ],
      ),
    );
  }

  String _getHtmlContent() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #ffffff;
    }
    #viewport {
      width: 100%;
      height: 100%;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: grab;
    }
    #viewport.dragging {
      cursor: grabbing;
      user-select: none;
    }
    #mermaid-container {
      display: flex;
      justify-content: center;
      align-items: center;
      transform-origin: center center;
      transition: none;
      position: relative;
    }
    .mermaid {
      text-align: center;
    }
    .mermaid svg {
      max-width: none !important;
    }
    .error {
      color: #dc2626;
      font-family: system-ui, -apple-system, sans-serif;
      font-size: 14px;
      padding: 20px;
      text-align: center;
    }
    .placeholder {
      color: #9ca3af;
      font-family: system-ui, -apple-system, sans-serif;
      font-size: 14px;
      padding: 40px;
      text-align: center;
    }
  </style>
</head>
<body>
  <div id="viewport">
    <div id="mermaid-container">
      <div class="mermaid" id="mermaid-diagram">
        <p class="placeholder">在左侧输入 Mermaid 代码开始创作...</p>
      </div>
    </div>
  </div>
  
  <script>
    // 禁用右键菜单
    document.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      return false;
    });
    
    mermaid.initialize({
      startOnLoad: false,
      theme: 'default',
      securityLevel: 'loose',
      flowchart: {
        useMaxWidth: false,
        htmlLabels: true,
      }
    });
    
    let currentZoom = 100;
    const container = document.getElementById('mermaid-container');
    const viewport = document.getElementById('viewport');
    
    // 通知 Flutter 的辅助函数
    function callFlutter(handlerName, ...args) {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler(handlerName, ...args);
      }
    }
    
    // 监听 ESC 键
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        callFlutter('onEscPressed');
      }
    });
    
    // 图片位置和缩放
    let translateX = 0;
    let translateY = 0;
    
    // 鼠标拖动功能 - 直接移动图片位置
    let isDragging = false;
    let startX, startY, startTranslateX, startTranslateY;
    
    function updateTransform() {
      container.style.transform = 'translate(' + translateX + 'px, ' + translateY + 'px) scale(' + (currentZoom / 100) + ')';
    }
    
    viewport.addEventListener('mousedown', (e) => {
      // 只响应左键
      if (e.button !== 0) return;
      
      isDragging = true;
      viewport.classList.add('dragging');
      startX = e.clientX;
      startY = e.clientY;
      startTranslateX = translateX;
      startTranslateY = translateY;
    });
    
    document.addEventListener('mouseleave', () => {
      isDragging = false;
      viewport.classList.remove('dragging');
    });
    
    document.addEventListener('mouseup', () => {
      isDragging = false;
      viewport.classList.remove('dragging');
    });
    
    document.addEventListener('mousemove', (e) => {
      if (!isDragging) return;
      e.preventDefault();
      const deltaX = e.clientX - startX;
      const deltaY = e.clientY - startY;
      translateX = startTranslateX + deltaX;
      translateY = startTranslateY + deltaY;
      updateTransform();
    });
    
    // 鼠标滚轮缩放（小幅度10%）
    viewport.addEventListener('wheel', (e) => {
      if (e.ctrlKey) {
        e.preventDefault();
        const delta = e.deltaY > 0 ? -10 : 10;
        currentZoom = Math.max(10, Math.min(1000, currentZoom + delta));
        updateTransform();
        callFlutter('onZoomChange', currentZoom);
      }
    }, { passive: false });
    
    function setZoom(percent) {
      currentZoom = percent;
      updateTransform();
    }
    
    function resetZoom() {
      currentZoom = 100;
      translateX = 0;
      translateY = 0;
      updateTransform();
      callFlutter('onZoomChange', 100);
    }
    
    async function renderMermaid(code) {
      const diagramDiv = document.getElementById('mermaid-diagram');
      
      if (!code || code.trim() === '') {
        diagramDiv.innerHTML = '<p class="placeholder">在左侧输入 Mermaid 代码开始创作...</p>';
        return;
      }
      
      try {
        // 每次渲染使用唯一ID，避免冲突
        const id = 'diagram-' + Date.now();
        const { svg } = await mermaid.render(id, code);
        diagramDiv.innerHTML = svg;
        callFlutter('onMermaidResult', true);
      } catch (error) {
        callFlutter('onMermaidResult', false, error.message);
        diagramDiv.innerHTML = '<p class="error">语法错误，请检查代码</p>';
      }
    }
    
    function triggerExportPng() {
      const svg = document.querySelector('#mermaid-diagram svg');
      if (!svg) {
        return;
      }
      
      const svgData = new XMLSerializer().serializeToString(svg);
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      const img = new Image();
      
      img.onload = function() {
        // 使用 2x 分辨率获得更清晰的图片
        const scale = 2;
        canvas.width = img.width * scale;
        canvas.height = img.height * scale;
        
        // 填充白色背景
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        // 绘制图片
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        
        const dataUrl = canvas.toDataURL('image/png');
        callFlutter('onExportPng', dataUrl, canvas.width, canvas.height);
      };
      
      img.onerror = function(e) {
        console.error('PNG export failed:', e);
      };
      
      // 确保 SVG 有正确的命名空间
      let svgWithNS = svgData;
      if (!svgWithNS.includes('xmlns=')) {
        svgWithNS = svgWithNS.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
      }
      img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgWithNS)));
    }
    
    // 获取 SVG 尺寸
    function getSvgSize() {
      const svg = document.querySelector('#mermaid-diagram svg');
      if (!svg) {
        callFlutter('onSvgSize', 800, 600);
        return;
      }
      
      // 尝试从 viewBox 或 width/height 属性获取尺寸
      let width = svg.width?.baseVal?.value || svg.getBoundingClientRect().width;
      let height = svg.height?.baseVal?.value || svg.getBoundingClientRect().height;
      
      // 如果有 viewBox，优先使用
      const viewBox = svg.getAttribute('viewBox');
      if (viewBox) {
        const parts = viewBox.split(/[\\s,]+/);
        if (parts.length >= 4) {
          width = parseFloat(parts[2]) || width;
          height = parseFloat(parts[3]) || height;
        }
      }
      
      callFlutter('onSvgSize', Math.round(width), Math.round(height));
    }
    
    // 导出指定尺寸的 PNG
    function triggerExportPngWithSize(targetWidth, targetHeight) {
      const svg = document.querySelector('#mermaid-diagram svg');
      if (!svg) {
        return;
      }
      
      // 克隆 SVG 并设置新尺寸
      const svgClone = svg.cloneNode(true);
      
      // 获取原始尺寸用于计算
      let origWidth = svg.width?.baseVal?.value || svg.getBoundingClientRect().width;
      let origHeight = svg.height?.baseVal?.value || svg.getBoundingClientRect().height;
      
      const viewBox = svg.getAttribute('viewBox');
      if (viewBox) {
        const parts = viewBox.split(/[\\s,]+/);
        if (parts.length >= 4) {
          origWidth = parseFloat(parts[2]) || origWidth;
          origHeight = parseFloat(parts[3]) || origHeight;
        }
      }
      
      // 设置新的 viewBox 保持原始内容
      if (!svgClone.getAttribute('viewBox')) {
        svgClone.setAttribute('viewBox', '0 0 ' + origWidth + ' ' + origHeight);
      }
      
      // 设置目标尺寸
      svgClone.setAttribute('width', targetWidth);
      svgClone.setAttribute('height', targetHeight);
      
      const svgData = new XMLSerializer().serializeToString(svgClone);
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      const img = new Image();
      
      img.onload = function() {
        canvas.width = targetWidth;
        canvas.height = targetHeight;
        
        // 填充白色背景
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        // 绘制图片
        ctx.drawImage(img, 0, 0, targetWidth, targetHeight);
        
        const dataUrl = canvas.toDataURL('image/png');
        callFlutter('onExportPng', dataUrl, targetWidth, targetHeight);
      };
      
      img.onerror = function(e) {
        console.error('PNG export with size failed:', e);
      };
      
      // 确保 SVG 有正确的命名空间
      let svgWithNS = svgData;
      if (!svgWithNS.includes('xmlns=')) {
        svgWithNS = svgWithNS.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
      }
      img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgWithNS)));
    }
    
    function triggerExportSvg() {
      const svg = document.querySelector('#mermaid-diagram svg');
      if (!svg) {
        return;
      }
      
      let svgData = new XMLSerializer().serializeToString(svg);
      // 确保有 XML 声明和命名空间
      if (!svgData.includes('xmlns=')) {
        svgData = svgData.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
      }
      callFlutter('onExportSvg', svgData);
    }
  </script>
</body>
</html>
''';
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: Colors.black54),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

/// 全屏模式下的导航按钮
class _FullscreenNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final Alignment alignment;
  final bool iconOnRight;

  const _FullscreenNavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onPressed,
    required this.alignment,
    this.iconOnRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : Colors.white38;

    final iconWidget = Icon(icon, size: 16, color: color);
    final textWidget = Flexible(
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Align(
      alignment: alignment,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: iconOnRight
                  ? [textWidget, const SizedBox(width: 6), iconWidget]
                  : [iconWidget, const SizedBox(width: 6), textWidget],
            ),
          ),
        ),
      ),
    );
  }
}
