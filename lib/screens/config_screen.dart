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

  // 持久的输入控制器（在 initState 中创建，避免 build 中重复创建）
  late final TextEditingController _llmBaseUrlController;
  late final TextEditingController _llmModelController;
  late final TextEditingController _llmApiKeyController;
  late final TextEditingController _videoBaseUrlController;
  late final TextEditingController _videoModelController;
  late final TextEditingController _videoApiKeyController;
  late final TextEditingController _imageBaseUrlController;
  late final TextEditingController _imageModelController;
  late final TextEditingController _imageApiKeyController;

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

    // 初始化所有输入控制器（只创建一次）
    _llmBaseUrlController = TextEditingController(text: _config.llmBaseUrl);
    _llmModelController = TextEditingController(text: _config.llmModel);
    _llmApiKeyController = TextEditingController(text: _config.llmApiKey);
    _videoBaseUrlController = TextEditingController(text: _config.videoBaseUrl);
    _videoModelController = TextEditingController(text: _config.videoModel);
    _videoApiKeyController = TextEditingController(text: _config.videoApiKey);
    _imageBaseUrlController = TextEditingController(text: _config.imageBaseUrl);
    _imageModelController = TextEditingController(text: _config.imageModel);
    _imageApiKeyController = TextEditingController(text: _config.imageApiKey);

    _initHeaderControllers();
  }

  void _initHeaderControllers() {
    _config.llmHeaders.forEach((k, v) {
      _llmHeaderKeyControllers.add(TextEditingController(text: k));
      _llmHeaderValueControllers.add(TextEditingController(text: v));
    });
    _config.videoHeaders.forEach((k, v) {
      _videoHeaderKeyControllers.add(TextEditingController(text: k));
      _videoHeaderValueControllers.add(TextEditingController(text: v));
    });
    _config.imageHeaders.forEach((k, v) {
      _imageHeaderKeyControllers.add(TextEditingController(text: k));
      _imageHeaderValueControllers.add(TextEditingController(text: v));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _llmBaseUrlController.dispose();
    _llmModelController.dispose();
    _llmApiKeyController.dispose();
    _videoBaseUrlController.dispose();
    _videoModelController.dispose();
    _videoApiKeyController.dispose();
    _imageBaseUrlController.dispose();
    _imageModelController.dispose();
    _imageApiKeyController.dispose();
    for (var c in _llmHeaderKeyControllers) c.dispose();
    for (var c in _llmHeaderValueControllers) c.dispose();
    for (var c in _videoHeaderKeyControllers) c.dispose();
    for (var c in _videoHeaderValueControllers) c.dispose();
    for (var c in _imageHeaderKeyControllers) c.dispose();
    for (var c in _imageHeaderValueControllers) c.dispose();
    super.dispose();
  }

  void _saveConfig() {
    // 从控制器读取值
    _config.llmBaseUrl = _llmBaseUrlController.text.trim();
    _config.llmModel = _llmModelController.text.trim();
    _config.llmApiKey = _llmApiKeyController.text.trim();
    _config.videoBaseUrl = _videoBaseUrlController.text.trim();
    _config.videoModel = _videoModelController.text.trim();
    _config.videoApiKey = _videoApiKeyController.text.trim();
    _config.imageBaseUrl = _imageBaseUrlController.text.trim();
    _config.imageModel = _imageModelController.text.trim();
    _config.imageApiKey = _imageApiKeyController.text.trim();

    // 收集 Headers
    _config.llmHeaders = {};
    for (var i = 0; i < _llmHeaderKeyControllers.length; i++) {
      final key = _llmHeaderKeyControllers[i].text.trim();
      final value = _llmHeaderValueControllers[i].text.trim();
      if (key.isNotEmpty) _config.llmHeaders[key] = value;
    }
    _config.videoHeaders = {};
    for (var i = 0; i < _videoHeaderKeyControllers.length; i++) {
      final key = _videoHeaderKeyControllers[i].text.trim();
      final value = _videoHeaderValueControllers[i].text.trim();
      if (key.isNotEmpty) _config.videoHeaders[key] = value;
    }
    _config.imageHeaders = {};
    for (var i = 0; i < _imageHeaderKeyControllers.length; i++) {
      final key = _imageHeaderKeyControllers[i].text.trim();
      final value = _imageHeaderValueControllers[i].text.trim();
      if (key.isNotEmpty) _config.imageHeaders[key] = value;
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
        title: const Text('API 配置'),
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

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
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
          _buildSectionTitle('协议类型'),
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
          _buildSectionTitle('API 地址'),
          _buildInputField(
            controller: _llmBaseUrlController,
            hintText: 'https://api.example.com/v1',
            icon: Icons.link,
          ),
          _buildSectionTitle('模型名称'),
          _buildInputField(
            controller: _llmModelController,
            hintText: 'gpt-4o / claude-3-5-sonnet / deepseek-chat',
            icon: Icons.smart_toy,
          ),
          _buildSectionTitle('API Key'),
          _buildInputField(
            controller: _llmApiKeyController,
            hintText: 'sk-...',
            icon: Icons.key,
            obscureText: true,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('思考模型'),
            subtitle: const Text('启用后自动识别 <think></think> 标签，思考内容默认折叠且不放入提示词'),
            value: _config.isThinkModel,
            onChanged: (v) => setState(() => _config.isThinkModel = v),
          ),
          const SizedBox(height: 16),
          _buildHeadersSection(
            keyControllers: _llmHeaderKeyControllers,
            valueControllers: _llmHeaderValueControllers,
            onAdd: () {
              setState(() {
                _llmHeaderKeyControllers.add(TextEditingController());
                _llmHeaderValueControllers.add(TextEditingController());
              });
            },
            onRemove: (index) {
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
          _buildSectionTitle('协议类型'),
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
          _buildSectionTitle('API 地址'),
          _buildInputField(
            controller: _videoBaseUrlController,
            hintText: 'https://api.example.com/v1',
            icon: Icons.link,
          ),
          _buildSectionTitle('模型名称'),
          _buildInputField(
            controller: _videoModelController,
            hintText: 'sora / kling / cogvideo',
            icon: Icons.movie,
          ),
          _buildSectionTitle('API Key'),
          _buildInputField(
            controller: _videoApiKeyController,
            hintText: 'sk-...',
            icon: Icons.key,
            obscureText: true,
          ),
          const SizedBox(height: 24),
          _buildHeadersSection(
            keyControllers: _videoHeaderKeyControllers,
            valueControllers: _videoHeaderValueControllers,
            onAdd: () {
              setState(() {
                _videoHeaderKeyControllers.add(TextEditingController());
                _videoHeaderValueControllers.add(TextEditingController());
              });
            },
            onRemove: (index) {
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
            _buildSectionTitle('API 地址'),
            _buildInputField(
              controller: _imageBaseUrlController,
              hintText: 'https://api.example.com/v1',
              icon: Icons.link,
            ),
            _buildSectionTitle('模型名称'),
            _buildInputField(
              controller: _imageModelController,
              hintText: 'dall-e-3 / midjourney / stable-diffusion',
              icon: Icons.image,
            ),
            _buildSectionTitle('API Key'),
            _buildInputField(
              controller: _imageApiKeyController,
              hintText: 'sk-...',
              icon: Icons.key,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _buildHeadersSection(
              keyControllers: _imageHeaderKeyControllers,
              valueControllers: _imageHeaderValueControllers,
              onAdd: () {
                setState(() {
                  _imageHeaderKeyControllers.add(TextEditingController());
                  _imageHeaderValueControllers.add(TextEditingController());
                });
              },
              onRemove: (index) {
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

  // Headers 管理区域
  Widget _buildHeadersSection({
    required List<TextEditingController> keyControllers,
    required List<TextEditingController> valueControllers,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('自定义请求头', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (keyControllers.isEmpty)
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
          )
        else
          ...List.generate(keyControllers.length, (index) {
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
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onRemove(index),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
