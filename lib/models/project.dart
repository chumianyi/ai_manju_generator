import 'dart:convert';
import 'shot.dart';

/// 漫剧项目
class ManjuProject {
  String id;
  String title;
  String originalScript; // 原始剧本
  List<Shot> shots; // 分镜列表
  String style; // 视频风格
  String aspectRatio; // 视频比例 9:16, 16:9, 1:1
  DateTime createdAt;
  DateTime updatedAt;
  String? mergedVideoPath; // 合并后的视频路径

  ManjuProject({
    required this.id,
    this.title = '未命名漫剧',
    this.originalScript = '',
    List<Shot>? shots,
    this.style = '动漫风格',
    this.aspectRatio = '9:16',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.mergedVideoPath,
  })  : shots = shots ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'originalScript': originalScript,
        'shots': shots.map((s) => s.toJson()).toList(),
        'style': style,
        'aspectRatio': aspectRatio,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'mergedVideoPath': mergedVideoPath,
      };

  factory ManjuProject.fromJson(Map<String, dynamic> json) => ManjuProject(
        id: json['id'] ?? '',
        title: json['title'] ?? '未命名漫剧',
        originalScript: json['originalScript'] ?? '',
        shots: (json['shots'] as List?)
                ?.map((s) => Shot.fromJson(s))
                .toList() ??
            [],
        style: json['style'] ?? '动漫风格',
        aspectRatio: json['aspectRatio'] ?? '9:16',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
        mergedVideoPath: json['mergedVideoPath'],
      );

  String toJsonString() => jsonEncode(toJson());

  factory ManjuProject.fromJsonString(String str) =>
      ManjuProject.fromJson(jsonDecode(str));
}
