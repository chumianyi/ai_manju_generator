import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/ai_config.dart';
import '../models/project.dart';
import '../models/shot.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../utils/parser.dart';
import '../widgets/shot_card.dart';
import '../widgets/think_panel.dart';
import 'generate_screen.dart';

/// 分镜生成页面
class ProjectScreen extends StatefulWidget {
  final AiConfig config;
  final ManjuProject? project;

  const ProjectScreen({
    super.key,
    required this.config,
    this.project,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late TextEditingController _scriptController;
  late TextEditingController _titleController;
  late AiService _aiService;
  late ManjuProject _project;

  bool _isGenerating = false;
  String _streamOutput = '';
  String? _thinkContent;
  List<Shot> _shots = [];

  // 风格和比例
  final List<String> _styles = [
    '动漫风格',
    '写实风格',
    '赛博朋克',
    '水彩风格',
    '油画风格',
    '像素风格',
    '3D渲染',
    '黑白漫画',
  ];
  final List<String> _ratios = ['9:16', '16:9', '1:1'];

  @override
  void initState() {
    super.initState();
    _aiService = AiService(widget.config);
    _project = widget.project ??
        ManjuProject(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        );
    _scriptController = TextEditingController(text: _project.originalScript);
    _titleController = TextEditingController(text: _project.title);
    _shots = List.from(_project.shots);
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // 流式生成分镜
  Future<void> _generateShots() async {
    if (_scriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入剧本内容')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _streamOutput = '';
      _thinkContent = null;
      _shots = [];
    });

    try {
      await for (final chunk in _aiService.generateShotsStream(_scriptController.text)) {
        setState(() {
          _streamOutput = chunk;
        });

        // 实时解析思考内容
        if (widget.config.isThinkModel) {
          final think = TagParser.extractThink(chunk);
          if (think != null) {
            setState(() => _thinkContent = think);
          }
        }

        // 实时解析已生成的镜头
        final parsed = TagParser.parseShots(chunk);
        if (parsed.isNotEmpty) {
          setState(() => _shots = parsed);
        }
      }

      // 最终解析
      final finalShots = TagParser.parseShots(_streamOutput);
      if (finalShots.isNotEmpty) {
        setState(() => _shots = finalShots);
      }

      // 保存项目
      _project.originalScript = _scriptController.text;
      _project.shots = _shots;
      await StorageService.saveProject(_project);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  // 停止生成
  void _stopGeneration() {
    setState(() => _isGenerating = false);
  }

  // 进入视频生成
  void _goToGenerate() {
    if (_shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先生成分镜')),
      );
      return;
    }

    _project.shots = _shots;
    _project.title = _titleController.text;
    StorageService.saveProject(_project);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateScreen(
          config: widget.config,
          project: _project,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(
            hintText: '输入漫剧标题',
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (v) => _project.title = v,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () {
              _project.originalScript = _scriptController.text;
              _project.shots = _shots;
              StorageService.saveProject(_project);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已保存')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 风格和比例选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _project.style,
                    decoration: const InputDecoration(
                      labelText: '视频风格',
                      isDense: true,
                    ),
                    items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _project.style = v ?? _project.style),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _project.aspectRatio,
                    decoration: const InputDecoration(
                      labelText: '视频比例',
                      isDense: true,
                    ),
                    items: _ratios.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _project.aspectRatio = v ?? _project.aspectRatio),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '剧本编辑'),
                      Tab(text: '分镜列表'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildScriptTab(),
                        _buildShotsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_isGenerating)
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _stopGeneration,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                  child: const Text('停止生成'),
                ),
              )
            else
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generateShots,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI 生成分镜'),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _shots.isNotEmpty ? _goToGenerate : null,
                icon: const Icon(Icons.movie),
                label: Text('生成视频 (${_shots.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 剧本编辑 Tab
  Widget _buildScriptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('剧本内容', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _scriptController,
            maxLines: null,
            minLines: 10,
            decoration: const InputDecoration(
              hintText: '在这里输入你的漫剧剧本...\n\nAI会自动将剧本拆分为多个镜头，每个镜头用 <镜头N></镜头N> 标签标记。',
            ),
          ),
          const SizedBox(height: 16),

          // 流式输出预览
          if (_isGenerating || _streamOutput.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_isGenerating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Text(
                  _isGenerating ? 'AI 正在生成分镜...' : 'AI 输出结果',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 思考内容（折叠）
            if (_thinkContent != null) ThinkPanel(content: _thinkContent!),

            // Markdown 渲染输出
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: MarkdownBody(
                data: _streamOutput.isEmpty ? '等待输出...' : _streamOutput,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 分镜列表 Tab
  Widget _buildShotsTab() {
    if (_shots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_creation_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              '暂无分镜',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            const Text(
              '在"剧本编辑"中输入剧本并点击"AI 生成分镜"',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _shots.length,
      itemBuilder: (context, index) {
        return ShotCard(
          shot: _shots[index],
          onEdit: (shot) {
            _project.shots = _shots;
            StorageService.saveProject(_project);
          },
        );
      },
    );
  }
}
