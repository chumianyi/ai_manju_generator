/// 单个分镜
class Shot {
  int index;
  String content; // 镜头描述/台词
  String? thinkContent; // 思考内容（如果有）
  String? videoPrompt; // 视频生成提示词
  String? videoPath; // 生成的视频本地路径
  String? videoUrl; // 视频URL
  bool isGenerating;
  bool isCompleted;
  String? error;

  Shot({
    required this.index,
    required this.content,
    this.thinkContent,
    this.videoPrompt,
    this.videoPath,
    this.videoUrl,
    this.isGenerating = false,
    this.isCompleted = false,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'content': content,
        'thinkContent': thinkContent,
        'videoPrompt': videoPrompt,
        'videoPath': videoPath,
        'videoUrl': videoUrl,
        'isGenerating': isGenerating,
        'isCompleted': isCompleted,
        'error': error,
      };

  factory Shot.fromJson(Map<String, dynamic> json) => Shot(
        index: json['index'] ?? 0,
        content: json['content'] ?? '',
        thinkContent: json['thinkContent'],
        videoPrompt: json['videoPrompt'],
        videoPath: json['videoPath'],
        videoUrl: json['videoUrl'],
        isGenerating: json['isGenerating'] ?? false,
        isCompleted: json['isCompleted'] ?? false,
        error: json['error'],
      );
}
