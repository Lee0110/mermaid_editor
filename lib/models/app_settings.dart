/// 应用设置模型
class AppSettings {
  final String storagePath;
  final double sidebarWidth;

  AppSettings({
    required this.storagePath,
    this.sidebarWidth = 250,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      storagePath: json['storagePath'] as String,
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 250,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storagePath': storagePath,
      'sidebarWidth': sidebarWidth,
    };
  }

  AppSettings copyWith({
    String? storagePath,
    double? sidebarWidth,
  }) {
    return AppSettings(
      storagePath: storagePath ?? this.storagePath,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    );
  }
}
