import '../models/shot.dart';

/// 标签解析工具
class TagParser {
  /// 从文本中提取镜头标签 <镜头1>...</镜头1>
  static List<Shot> parseShots(String text) {
    final shots = <Shot>[];

    // 匹配 <镜头N>...</镜头N> 或 <镜头 N>...</镜头 N>
    final regex = RegExp(
      r'<镜头\s*(\d+)\s*>([\s\S]*?)</镜头\s*\1\s*>',
      multiLine: true,
    );

    final matches = regex.allMatches(text);

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final index = int.tryParse(match.group(1) ?? '0') ?? 0;
        var content = match.group(2)?.trim() ?? '';

        // 提取思考内容
        String? thinkContent;
        final thinkMatch = RegExp(
          r'<think>([\s\S]*?)</think>',
          multiLine: true,
        ).firstMatch(content);
        if (thinkMatch != null) {
          thinkContent = thinkMatch.group(1)?.trim();
          // 从内容中移除思考标签
          content = content.replaceAll(
            RegExp(r'<think>[\s\S]*?</think>', multiLine: true),
            '',
          ).trim();
        }

        shots.add(Shot(
          index: index,
          content: content,
          thinkContent: thinkContent,
        ));
      }
    } else {
      // 如果没有镜头标签，按段落分割
      final paragraphs = text
          .split(RegExp(r'\n\s*\n'))
          .where((p) => p.trim().isNotEmpty)
          .toList();

      for (var i = 0; i < paragraphs.length; i++) {
        var content = paragraphs[i].trim();

        String? thinkContent;
        final thinkMatch = RegExp(
          r'<think>([\s\S]*?)</think>',
          multiLine: true,
        ).firstMatch(content);
        if (thinkMatch != null) {
          thinkContent = thinkMatch.group(1)?.trim();
          content = content.replaceAll(
            RegExp(r'<think>[\s\S]*?</think>', multiLine: true),
            '',
          ).trim();
        }

        if (content.isNotEmpty) {
          shots.add(Shot(
            index: i + 1,
            content: content,
            thinkContent: thinkContent,
          ));
        }
      }
    }

    // 按 index 排序
    shots.sort((a, b) => a.index.compareTo(b.index));
    return shots;
  }

  /// 从文本中提取思考标签内容（不放入提示词）
  static String? extractThink(String text) {
    final match = RegExp(
      r'<think>([\s\S]*?)</think>',
      multiLine: true,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  /// 移除思考标签（用于清理提示词）
  static String removeThinkTags(String text) {
    return text.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', multiLine: true),
      '',
    );
  }

  /// 移除镜头标签，保留纯内容
  static String removeShotTags(String text) {
    return text.replaceAllMapped(
      RegExp(r'<镜头\s*\d+\s*>([\s\S]*?)</镜头\s*\d+\s*>', multiLine: true),
      (m) => m.group(1) ?? '',
    );
  }

  /// 生成分镜系统提示词
  static String buildShotSystemPrompt() {
    return '''你是一位专业的漫画分镜师。请根据用户提供的剧本，将其拆分为多个镜头。

要求：
1. 每个镜头用 <镜头N>...</镜头N> 标签包裹，N 为镜头序号（从1开始）
2. 每个镜头包含：场景描述、角色动作、台词、镜头语言（特写/全景/中景等）
3. 镜头之间要有连贯性，符合漫画叙事节奏
4. 每个镜头描述简洁明了，适合后续生成视频
5. 如果是思考模型，可以在镜头内容中使用 <think></think> 标签记录思考过程，但思考内容不会用于视频生成

输出格式示例：
<镜头1>
【场景】清晨的街道，阳光透过树叶洒下
【角色】少女站在公交站，低头看手机
【镜头】中景，缓慢推近
【台词】"今天也要加油呢。"
</镜头1>

<镜头2>
...
</镜头2>''';
  }

  /// 生成视频提示词的系统提示
  static String buildVideoPromptSystemPrompt(String style) {
    return '''你是一位视频提示词专家。根据分镜内容，生成适合AI视频生成模型的英文提示词。

要求：
1. 提示词用英文，描述画面内容、风格、运镜方式
2. 风格设定：$style
3. 包含：主体描述、场景环境、光线氛围、镜头运动、画面比例
4. 简洁精准，不超过200词
5. 只输出提示词本身，不要解释或多余文字''';
  }
}
