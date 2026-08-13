import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import '../models/shot.dart';
import '../utils/parser.dart';

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

    final uri = Uri.parse('${config.llmBaseUrl}/chat/completions');
    final headers = _buildHeaders();

    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    request.body = body;

    final response = await request.send();

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('API请求失败 (${response.statusCode}): $errorBody');
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
  Stream<String> generateShotsStream(String script) async {
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
  Future<Map<String, dynamic>> generateVideo({
    required String prompt,
    required String aspectRatio,
    String? style,
  }) async {
    final uri = Uri.parse('${config.videoBaseUrl}/videos/generations');
    final headers = _buildHeaders(forVideo: true);
    headers['Accept'] = 'application/json';

    final body = jsonEncode({
      'model': config.videoModel,
      'prompt': prompt,
      'size': aspectRatio == '9:16'
          ? '720x1280'
          : aspectRatio == '16:9'
              ? '1280x720'
              : '1024x1024',
      if (style != null) 'style': style,
    });

    final response = await http.post(
      uri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('视频生成失败 (${response.statusCode}): ${response.body}');
    }

    return jsonDecode(response.body);
  }

  /// 查询视频生成任务状态
  Future<Map<String, dynamic>> getVideoTaskStatus(String taskId) async {
    final uri = Uri.parse('${config.videoBaseUrl}/videos/generations/$taskId');
    final headers = _buildHeaders(forVideo: true);
    headers['Accept'] = 'application/json';

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('查询任务失败 (${response.statusCode}): ${response.body}');
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
