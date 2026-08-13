import 'dart:convert';

/// AI 模型配置
class AiConfig {
  // 语言模型
  String llmBaseUrl;
  String llmModel;
  String llmApiKey;
  Map<String, String> llmHeaders;

  // 视频模型
  String videoBaseUrl;
  String videoModel;
  String videoApiKey;
  Map<String, String> videoHeaders;

  // 图片模型（可选）
  bool enableImageModel;
  String imageBaseUrl;
  String imageModel;
  String imageApiKey;
  Map<String, String> imageHeaders;

  // 协议类型
  String llmProtocol; // openai, custom
  String videoProtocol;

  // 思考模型
  bool isThinkModel;

  AiConfig({
    this.llmBaseUrl = 'https://api.openai.com/v1',
    this.llmModel = 'gpt-4o',
    this.llmApiKey = '',
    Map<String, String>? llmHeaders,
    this.videoBaseUrl = '',
    this.videoModel = '',
    this.videoApiKey = '',
    Map<String, String>? videoHeaders,
    this.enableImageModel = false,
    this.imageBaseUrl = '',
    this.imageModel = '',
    this.imageApiKey = '',
    Map<String, String>? imageHeaders,
    this.llmProtocol = 'openai',
    this.videoProtocol = 'openai',
    this.isThinkModel = false,
  })  : llmHeaders = llmHeaders ?? {},
        videoHeaders = videoHeaders ?? {},
        imageHeaders = imageHeaders ?? {};

  Map<String, dynamic> toJson() => {
        'llmBaseUrl': llmBaseUrl,
        'llmModel': llmModel,
        'llmApiKey': llmApiKey,
        'llmHeaders': llmHeaders,
        'videoBaseUrl': videoBaseUrl,
        'videoModel': videoModel,
        'videoApiKey': videoApiKey,
        'videoHeaders': videoHeaders,
        'enableImageModel': enableImageModel,
        'imageBaseUrl': imageBaseUrl,
        'imageModel': imageModel,
        'imageApiKey': imageApiKey,
        'imageHeaders': imageHeaders,
        'llmProtocol': llmProtocol,
        'videoProtocol': videoProtocol,
        'isThinkModel': isThinkModel,
      };

  factory AiConfig.fromJson(Map<String, dynamic> json) => AiConfig(
        llmBaseUrl: json['llmBaseUrl'] ?? '',
        llmModel: json['llmModel'] ?? '',
        llmApiKey: json['llmApiKey'] ?? '',
        llmHeaders: Map<String, String>.from(json['llmHeaders'] ?? {}),
        videoBaseUrl: json['videoBaseUrl'] ?? '',
        videoModel: json['videoModel'] ?? '',
        videoApiKey: json['videoApiKey'] ?? '',
        videoHeaders: Map<String, String>.from(json['videoHeaders'] ?? {}),
        enableImageModel: json['enableImageModel'] ?? false,
        imageBaseUrl: json['imageBaseUrl'] ?? '',
        imageModel: json['imageModel'] ?? '',
        imageApiKey: json['imageApiKey'] ?? '',
        imageHeaders: Map<String, String>.from(json['imageHeaders'] ?? {}),
        llmProtocol: json['llmProtocol'] ?? 'openai',
        videoProtocol: json['videoProtocol'] ?? 'openai',
        isThinkModel: json['isThinkModel'] ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory AiConfig.fromJsonString(String str) =>
      AiConfig.fromJson(jsonDecode(str));
}
