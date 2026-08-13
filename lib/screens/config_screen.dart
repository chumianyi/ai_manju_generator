import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../services/storage_service.dart';

/// AI 模型配置页面
class ConfigScreen extends StatefulWidget {
  final AiConfig config;
  final Function(AiConfig) onSave;

  const ConfigScreen({
    super.key,
    required this.config,
    required this.onSave,
  });

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AiConfig _config;

  // Headers 编辑控制器
  final List<TextEditingController> _llmHeaderKeyControllers = [];
  final List<TextEditingController> _llmHeaderValueControllers = [];
  final List<TextEditingController> _videoHeaderKeyControllers = [];
  final List<TextEditingController> _videoHeaderValueControllers = [];
  final List<TextEditingController> _imageHeaderKeyControllers = [];
  final List<TextEditingController> _imageHeaderValueControllers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _config = AiConfig.fromJson(widget.config.toJson());
    _initHeaderControllers();
  }

  void _initHeaderControllers() {
    // LLM Headers
    _config.llmHeaders.forEach((k, v) {
      _llmHeaderKeyControllers.add(TextEditingController(text: k));
      _llmHeaderValueControllers.add(TextEditingController(text: v));
    });
    // Video Headers
    _config.videoHeaders.forEach((k, v) {
      _videoHeaderKeyControllers.add(TextEditingController(text: k));
      _videoHeaderValueControllers.add(TextEditingController(text: v));
    });
    // Image Headers
    _config.imageHeaders.forEach((k, v) {
      _imageHeaderKeyControllers.add(TextEditingController(text: k));
      _imageHeaderValueControllers.add(TextEditingController(text: v));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var c in _llmHeaderKeyControllers) {
      c.dispose();
    }
    for (var c in _llmHeaderValueControllers) {
      c.dispose();
    }
    for (var c in _videoHeaderKeyControllers) {
      c.dispose();
    }
    for (var c in _videoHeaderValueControllers) {
      c.dispose();
    }
    for (var c in _imageHeaderKeyControllers) {
      c.dispose();
    }
    for (var c in _imageHeaderValueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveConfig() {
    // 收集 Headers
    _config.llmHeaders = {};
    for (var i = 0; i < _llmHeaderKeyControllers.length; i++) {
      final key = _llmHeaderKeyControllers[i].text.trim();
      final value = _llmHeaderValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        _config.llmHeaders[key] = value;
      }
    }
    _config.videoHeaders = {};
    for (var i = 0; i < _videoHeaderKeyControllers.length; i++) {
      final key = _videoHeaderKeyControllers[i].text.trim();
      final value = _videoHeaderValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        _config.videoHeaders[key] = value;
      }
    }
    _config.imageHeaders = {};
    for (var i = 0; i < _imageHeaderKeyControllers.length; i++) {
      final key = _imageHeaderKeyControllers[i].text.trim();
      final value = _imageHeaderValueControllers[i].text.trim();
      if (key.isNotEmpty) {
        _config.imageHeaders[key] = value;
      }
    }

    StorageService.saveConfig(_config);
    widget.onSave(_config);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 模型配置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '语言模型'),
            Tab(text: '视频模型'),
            Tab(text: '图片模型'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLlmConfig(),
          _buildVideoConfig(),
          _buildImageConfig(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveConfig,
        icon: const Icon(Icons.save),
        label: const Text('保存配置'),
      ),
    );
  }

  // 语言模型配置
  Widget _buildLlmConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 协议选择
          Text('协议类型', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'openai', label: Text('OpenAI 兼容')),
              ButtonSegment(value: 'custom', label: Text('自定义')),
            ],
            selected: {_config.llmProtocol},
            onSelectionChanged: (s) {
              setState(() => _config.llmProtocol = s.first);
            },
          ),
          const SizedBox(height: 24),

          // API 地址
          Text('API 地址', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.llmBaseUrl),
            decoration: const InputDecoration(
              hintText: 'https://api.openai.com/v1',
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (v) => _config.llmBaseUrl = v,
          ),
          const SizedBox(height: 16),

          // 模型名
          Text('模型名称', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.llmModel),
            decoration: const InputDecoration(
              hintText: 'gpt-4o / claude-3-5-sonnet / deepseek-chat',
              prefixIcon: Icon(Icons.smart_toy),
            ),
            onChanged: (v) => _config.llmModel = v,
          ),
          const SizedBox(height: 16),

          // API Key
          Text('API Key', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.llmApiKey),
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'sk-...',
              prefixIcon: Icon(Icons.key),
            ),
            onChanged: (v) => _config.llmApiKey = v,
          ),
          const SizedBox(height: 24),

          // 思考模型开关
          SwitchListTile(
            title: const Text('思考模型'),
            subtitle: const Text('启用后自动识别 <think></think> 标签，思考内容默认折叠且不放入提示词'),
            value: _config.isThinkModel,
            onChanged: (v) => setState(() => _config.isThinkModel = v),
          ),
          const SizedBox(height: 16),

          // 自定义 Headers
          Row(
            children: [
              Text('自定义请求头', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _llmHeaderKeyControllers.add(TextEditingController());
                    _llmHeaderValueControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._buildHeaderEditors(
            _llmHeaderKeyControllers,
            _llmHeaderValueControllers,
            (index) {
              setState(() {
                _llmHeaderKeyControllers[index].dispose();
                _llmHeaderValueControllers[index].dispose();
                _llmHeaderKeyControllers.removeAt(index);
                _llmHeaderValueControllers.removeAt(index);
              });
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // 视频模型配置
  Widget _buildVideoConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('协议类型', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'openai', label: Text('OpenAI 兼容')),
              ButtonSegment(value: 'custom', label: Text('自定义')),
            ],
            selected: {_config.videoProtocol},
            onSelectionChanged: (s) {
              setState(() => _config.videoProtocol = s.first);
            },
          ),
          const SizedBox(height: 24),
          Text('API 地址', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.videoBaseUrl),
            decoration: const InputDecoration(
              hintText: 'https://api.example.com/v1',
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (v) => _config.videoBaseUrl = v,
          ),
          const SizedBox(height: 16),
          Text('模型名称', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.videoModel),
            decoration: const InputDecoration(
              hintText: 'sora / kling / cogvideo',
              prefixIcon: Icon(Icons.movie),
            ),
            onChanged: (v) => _config.videoModel = v,
          ),
          const SizedBox(height: 16),
          Text('API Key', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: _config.videoApiKey),
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'sk-...',
              prefixIcon: Icon(Icons.key),
            ),
            onChanged: (v) => _config.videoApiKey = v,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('自定义请求头', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _videoHeaderKeyControllers.add(TextEditingController());
                    _videoHeaderValueControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._buildHeaderEditors(
            _videoHeaderKeyControllers,
            _videoHeaderValueControllers,
            (index) {
              setState(() {
                _videoHeaderKeyControllers[index].dispose();
                _videoHeaderValueControllers[index].dispose();
                _videoHeaderKeyControllers.removeAt(index);
                _videoHeaderValueControllers.removeAt(index);
              });
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // 图片模型配置
  Widget _buildImageConfig() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('启用图片模型'),
            subtitle: const Text('可选，用于生成镜头参考图'),
            value: _config.enableImageModel,
            onChanged: (v) => setState(() => _config.enableImageModel = v),
          ),
          if (_config.enableImageModel) ...[
            const SizedBox(height: 16),
            Text('API 地址', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _config.imageBaseUrl),
              decoration: const InputDecoration(
                hintText: 'https://api.example.com/v1',
                prefixIcon: Icon(Icons.link),
              ),
              onChanged: (v) => _config.imageBaseUrl = v,
            ),
            const SizedBox(height: 16),
            Text('模型名称', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _config.imageModel),
              decoration: const InputDecoration(
                hintText: 'dall-e-3 / midjourney / stable-diffusion',
                prefixIcon: Icon(Icons.image),
              ),
              onChanged: (v) => _config.imageModel = v,
            ),
            const SizedBox(height: 16),
            Text('API Key', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: _config.imageApiKey),
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                prefixIcon: Icon(Icons.key),
              ),
              onChanged: (v) => _config.imageApiKey = v,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('自定义请求头', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _imageHeaderKeyControllers.add(TextEditingController());
                      _imageHeaderValueControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildHeaderEditors(
              _imageHeaderKeyControllers,
              _imageHeaderValueControllers,
              (index) {
                setState(() {
                  _imageHeaderKeyControllers[index].dispose();
                  _imageHeaderValueControllers[index].dispose();
                  _imageHeaderKeyControllers.removeAt(index);
                  _imageHeaderValueControllers.removeAt(index);
                });
              },
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Headers 编辑器
  List<Widget> _buildHeaderEditors(
    List<TextEditingController> keyControllers,
    List<TextEditingController> valueControllers,
    Function(int) onRemove,
  ) {
    if (keyControllers.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '暂无自定义请求头，点击上方"添加"按钮',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ),
      ];
    }

    return List.generate(keyControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: keyControllers[index],
                decoration: const InputDecoration(
                  hintText: 'Header 名称',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: valueControllers[index],
                decoration: const InputDecoration(
                  hintText: 'Header 值',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => onRemove(index),
            ),
          ],
        ),
      );
    });
  }
}
