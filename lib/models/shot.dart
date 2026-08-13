/// 镜头生成状态
enum ShotStatus {
  pending,      // 等待中
  queued,       // 队列中
  generating,   // 生成中
  completed,    // 已完成
  failed,       // 失败
}

/// 单个分镜
class Shot {
  int index;
  String content; // 镜头描述/台词
  String? thinkContent; // 思考内容（如果有）
  String? videoPrompt; // 视频生成提示词
  String? videoPath; // 生成的视频本地路径
  String? videoUrl; // 视频URL
  double progress; // 生成进度 0.0 - 1.0
  ShotStatus status; // 生成状态
  String? error;

  // 兼容旧字段
  bool get isGenerating => status == ShotStatus.generating;
  bool get isCompleted => status == ShotStatus.completed;

  Shot({
    required this.index,
    required this.content,
    this.thinkContent,
    this.videoPrompt,
    this.videoPath,
    this.videoUrl,
    this.progress = 0.0,
    this.status = ShotStatus.pending,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'content': content,
        'thinkContent': thinkContent,
        'videoPrompt': videoPrompt,
        'videoPath': videoPath,
        'videoUrl': videoUrl,
        'progress': progress,
        'status': status.index,
        'error': error,
      };

  factory Shot.fromJson(Map<String, dynamic> json) => Shot(
        index: json['index'] ?? 0,
        content: json['content'] ?? '',
        thinkContent: json['thinkContent'],
        videoPrompt: json['videoPrompt'],
        videoPath: json['videoPath'],
        videoUrl: json['videoUrl'],
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] != null
            ? ShotStatus.values[json['status']]
            : (json['isCompleted'] == true ? ShotStatus.completed : ShotStatus.pending),
        error: json['error'],
      );
}
