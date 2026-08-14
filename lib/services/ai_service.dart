import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import '../models/shot.dart';
import '../utils/parser.dart';

/// AI 错误类型
enum AiErrorType {
  rateLimit,      // 使用人数过多/限流
  invalidApiKey,  // API Key 无效
  networkError,   // 网络错误
  modelNotFound,  // 模型不存在
  serverError,    // 服务器错误
  unknown,        // 未知错误
}

/// AI 异常 - 友好的错误信息
class AiException implements Exception {
  final AiErrorType type;
  final String message;
  final int? statusCode;
  final String? rawBody;

  AiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.rawBody,
  });

  @override
  String toString() => message;

  /// 是否可以重试
  bool get canRetry => type == AiErrorType.rateLimit || type == AiErrorType.networkError || type == AiErrorType.serverError;
}

/// 从 HTTP 响应识别错误类型
AiException _parseHttpError(int statusCode, String body) {
  final lowerBody = body.toLowerCase();

  // 429 限流
  if (statusCode == 429) {
    return AiException(
      type: AiErrorType.rateLimit,
      message: '当前使用人数过多，请稍后重试',
      statusCode: statusCode,
      rawBody: body,
    );
  }

  // 401/403 API Key 错误
  if (statusCode == 401 || statusCode == 403) {
    if (lowerBody.contains('invalid') || lowerBody.contains('unauthorized') || lowerBody.contains('api_key') || lowerBody.contains('key')) {
      return AiException(
        type: AiErrorType.invalidApiKey,
        message: 'API Key 无效，请检查配置',
        statusCode: statusCode,
        rawBody: body,
      );
    }
  }

  // 404 模型不存在
  if (statusCode == 404) {
    if (lowerBody.contains('model') || lowerBody.contains('not found') || lowerBody.contains('不存在')) {
      return AiException(
        type: AiErrorType.modelNotFound,
        message: '模型不存在，请检查模型名称',
        statusCode: statusCode,
        rawBody: body,
      );
    }
    return AiException(
      type: AiErrorType.modelNotFound,
      message: 'API 地址不存在，请检查 API 地址是否正确',
      statusCode: statusCode,
      rawBody: body,
    );
  }

  // 5xx 服务器错误
  if (statusCode >= 500) {
    return AiException(
      type: AiErrorType.serverError,
      message: '服务器繁忙，请稍后重试',
      statusCode: statusCode,
      rawBody: body,
    );
  }

  // 检查 body 中的限流关键词
  if (lowerBody.contains('rate limit') ||
      lowerBody.contains('rate_limit') ||
      lowerBody.contains('too many requests') ||
      lowerBody.contains('使用人数过多') ||
      lowerBody.contains('排队') ||
      lowerBody.contains('繁忙') ||
      lowerBody.contains('concurrent') ||
      lowerBody.contains('quota')) {
    return AiException(
      type: AiErrorType.rateLimit,
      message: '当前使用人数过多，请稍后重试',
      statusCode: statusCode,
      rawBody: body,
    );
  }

  // 检查 API Key 错误关键词
  if (lowerBody.contains('invalid api key') ||
      lowerBody.contains('incorrect api key') ||
      lowerBody.contains('api key not found') ||
      lowerBody.contains('invalid key') ||
      lowerBody.contains('密钥') ||
      lowerBody.contains('key无效')) {
    return AiException(
      type: AiErrorType.invalidApiKey,
      message: 'API Key 无效，请检查配置',
      statusCode: statusCode,
      rawBody: body,
    );
  }

  return AiException(
    type: AiErrorType.unknown,
    message: '请求失败 ($statusCode): ${body.length > 200 ? body.substring(0, 200) : body}',
    statusCode: statusCode,
    rawBody: body,
  );
}

/// 聊天消息
class ChatMessage {
  final String role; // system, user, assistant
  final String content;
  String? thinkContent; // 思考内容（不放入后续提示词）

  ChatMessage({
    required this.role,
    required this.content,
    this.thinkContent,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// AI 服务 - 核心：多轮对话累积 + 流式输出
class AiService {
  final AiConfig config;

  // 对话历史 - 累积所有对话，实现"垒起来"的效果
  final List<ChatMessage> _conversationHistory = [];
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);

  AiService(this.config);

  /// 清空对话历史
  void clearHistory() {
    _conversationHistory.clear();
  }

  /// 添加系统消息
  void addSystemMessage(String content) {
    _conversationHistory.add(ChatMessage(role: 'system', content: content));
  }

  /// 添加用户消息
  void addUserMessage(String content) {
    _conversationHistory.add(ChatMessage(role: 'user', content: content));
  }

  /// 添加助手消息
  void addAssistantMessage(String content, {String? thinkContent}) {
    _conversationHistory.add(ChatMessage(
      role: 'assistant',
      content: content,
      thinkContent: thinkContent,
    ));
  }

  /// 构建请求头（包含自定义 Headers）
  Map<String, String> _buildHeaders({bool forVideo = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    };

    if (forVideo) {
      if (config.videoApiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${config.videoApiKey}';
      }
      headers.addAll(config.videoHeaders);
    } else {
      if (config.llmApiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${config.llmApiKey}';
      }
      headers.addAll(config.llmHeaders);
    }

    return headers;
  }

  /// 流式聊天 - 核心方法
  /// 每次调用都累积历史对话，实现"一句话跑多次接口，把对话垒起来"
  Stream<String> streamChat({
    String? systemPrompt,
    required String userMessage,
    bool addToHistory = true,
  }) async* {
    // 构建消息列表：历史 + 当前
    final messages = <Map<String, dynamic>>[];

    // 先加系统提示
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }

    // 加入历史对话（累积）
    for (final msg in _conversationHistory) {
      // 思考内容不放入提示词
      messages.add(msg.toJson());
    }

    // 加入当前用户消息
    messages.add({'role': 'user', 'content': userMessage});

    final body = jsonEncode({
      'model': config.llmModel,
      'messages': messages,
      'stream': true,
      'temperature': 0.7,
      'max_tokens': 16384,
    });

    final baseUrl = config.llmBaseUrl.endsWith('/')
        ? config.llmBaseUrl.substring(0, config.llmBaseUrl.length - 1)
        : config.llmBaseUrl;
    final uri = Uri.parse('$baseUrl/chat/completions');
    final headers = _buildHeaders();

    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    request.body = body;

    final response = await request.send();

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw _parseHttpError(response.statusCode, errorBody);
    }

    final completer = Completer<void>();
    final buffer = StringBuffer();
    String? thinkBuffer;
    bool inThink = false;

    response.stream.transform(utf8.decoder).listen(
      (data) {
        // 解析 SSE
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final payload = line.substring(6);
            if (payload.trim() == '[DONE]') {
              completer.complete();
              continue;
            }
            try {
              final json = jsonDecode(payload);
              final delta = json['choices']?[0]?['delta']?['content'];
              if (delta != null && delta is String) {
                buffer.write(delta);
              }
            } catch (_) {
              // 忽略解析错误
            }
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    // 逐字输出流
    String lastOutput = '';
    while (!completer.isCompleted) {
      await Future.delayed(const Duration(milliseconds: 50));
      final current = buffer.toString();
      if (current.length > lastOutput.length) {
        final newPart = current.substring(lastOutput.length);
        lastOutput = current;
        yield newPart;
      }
    }

    // 输出剩余部分
    final current = buffer.toString();
    if (current.length > lastOutput.length) {
      yield current.substring(lastOutput.length);
    }

    final fullContent = buffer.toString();

    // 处理思考标签
    String? thinkContent;
    String cleanContent = fullContent;

    if (config.isThinkModel) {
      thinkContent = TagParser.extractThink(fullContent);
      cleanContent = TagParser.removeThinkTags(fullContent).trim();
    }

    // 加入历史（累积）
    if (addToHistory) {
      addUserMessage(userMessage);
      addAssistantMessage(cleanContent, thinkContent: thinkContent);
    }
  }

  /// 非流式聊天（用于简单调用）
  Future<String> chat({
    String? systemPrompt,
    required String userMessage,
    bool addToHistory = true,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in streamChat(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      addToHistory: addToHistory,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// 生成分镜
  Stream<String> generateShotsStream(String script) async* {
    clearHistory();
    final systemPrompt = TagParser.buildShotSystemPrompt();

    final buffer = StringBuffer();
    await for (final chunk in streamChat(
      systemPrompt: systemPrompt,
      userMessage: '请将以下剧本拆分为镜头：\n\n$script',
      addToHistory: true,
    )) {
      buffer.write(chunk);
      yield buffer.toString();
    }
  }

  /// 从流式输出中解析分镜
  List<Shot> parseShotsFromOutput(String text) {
    return TagParser.parseShots(text);
  }

  /// 为单个镜头生成视频提示词（多轮累积）
  Future<String> generateVideoPrompt(
    Shot shot,
    String style, {
    Function(String)? onStream,
  }) async {
    final systemPrompt = TagParser.buildVideoPromptSystemPrompt(style);
    final userMsg = '镜头${shot.index}内容：\n${shot.content}\n\n请生成视频提示词。';

    final buffer = StringBuffer();
    await for (final chunk in streamChat(
      systemPrompt: systemPrompt,
      userMessage: userMsg,
      addToHistory: true,
    )) {
      buffer.write(chunk);
      onStream?.call(buffer.toString());
    }
    return buffer.toString().trim();
  }

  /// 调用视频模型生成视频
  /// 根据比例和清晰度计算分辨率
  /// 判断是否为智谱视频模型
  bool get _isZhipuVideo => config.videoBaseUrl.contains('bigmodel.cn');

  /// 智谱支持的分辨率枚举
  String _zhipuResolution(String aspectRatio, String quality) {
    final resolutions = {
      '480p': {'9:16': '720x1280', '16:9': '1280x720', '1:1': '1024x1024'},
      '720p': {'9:16': '720x1280', '16:9': '1280x720', '1:1': '1024x1024'},
      '1080p': {'9:16': '1080x1920', '16:9': '1920x1080', '1:1': '1024x1024'},
      '4K': {'9:16': '1080x1920', '16:9': '3840x2160', '1:1': '1024x1024'},
    };
    return resolutions[quality]?[aspectRatio] ?? '720x1280';
  }

  String _calcResolution(String aspectRatio, String quality) {
    if (_isZhipuVideo) return _zhipuResolution(aspectRatio, quality);
    final resolutions = {
      '480p': {'9:16': '480x854', '16:9': '854x480', '1:1': '480x480'},
      '720p': {'9:16': '720x1280', '16:9': '1280x720', '1:1': '720x720'},
      '1080p': {'9:16': '1080x1920', '16:9': '1920x1080', '1:1': '1080x1080'},
      '4K': {'9:16': '2160x3840', '16:9': '3840x2160', '1:1': '2160x2160'},
    };
    return resolutions[quality]?[aspectRatio] ?? '720x1280';
  }

  Future<Map<String, dynamic>> generateVideo({
    required String prompt,
    required String aspectRatio,
    String quality = '720p',
    String? style,
  }) async {
    final baseUrl = config.videoBaseUrl.endsWith('/')
        ? config.videoBaseUrl.substring(0, config.videoBaseUrl.length - 1)
        : config.videoBaseUrl;
    final uri = Uri.parse('$baseUrl/videos/generations');
    final headers = _buildHeaders(forVideo: true);
    headers['Accept'] = 'application/json';

    final bodyMap = <String, dynamic>{
      'model': config.videoModel,
      'prompt': prompt,
      'size': _calcResolution(aspectRatio, quality),
    };

    if (_isZhipuVideo) {
      // 智谱特有参数
      bodyMap['quality'] = 'quality'; // 质量优先
      bodyMap['duration'] = 5;
    } else {
      bodyMap['quality'] = quality;
      if (style != null) bodyMap['style'] = style;
    }

    final body = jsonEncode(bodyMap);

    final response = await http.post(
      uri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw _parseHttpError(response.statusCode, response.body);
    }

    return jsonDecode(response.body);
  }

  /// 查询视频生成任务状态
  Future<Map<String, dynamic>> getVideoTaskStatus(String taskId) async {
    final baseUrl = config.videoBaseUrl.endsWith('/')
        ? config.videoBaseUrl.substring(0, config.videoBaseUrl.length - 1)
        : config.videoBaseUrl;

    // 智谱使用 async-result 接口
    final uri = _isZhipuVideo
        ? Uri.parse('$baseUrl/async-result/$taskId')
        : Uri.parse('$baseUrl/videos/generations/$taskId');
    final headers = _buildHeaders(forVideo: true);
    headers['Accept'] = 'application/json';

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw _parseHttpError(response.statusCode, response.body);
    }

    return jsonDecode(response.body);
  }

  /// 下载视频到本地
  Future<String> downloadVideo(String url, String savePath) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('视频下载失败 (${response.statusCode})');
    }
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
    return savePath;
  }
}
