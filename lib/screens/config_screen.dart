import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../services/storage_service.dart';

/// 模型提供商预设
class ModelProvider {
  final String name;
  final String baseUrl;
  final List<String> recommendedModels;

  const ModelProvider({
    required this.name,
    required this.baseUrl,
    this.recommendedModels = const [],
  });
}

/// 语言模型提供商预设
const List<ModelProvider> _llmProviders = [
  ModelProvider(name: '自定义', baseUrl: ''),
  ModelProvider(name: 'OpenAI', baseUrl: 'https://api.openai.com/v1', recommendedModels: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo']),
  ModelProvider(name: '智谱AI / GLM', baseUrl: 'https://open.bigmodel.cn/api/paas/v4', recommendedModels: ['glm-4', 'glm-4-plus', 'glm-4-flash', 'glm-4-air']),
  ModelProvider(name: 'Anthropic / Claude', baseUrl: 'https://api.anthropic.com/v1', recommendedModels: ['claude-3-5-sonnet-20240620', 'claude-3-opus-20240229', 'claude-3-haiku-20240307']),
  ModelProvider(name: 'Google / Gemini', baseUrl: 'https://generativelanguage.googleapis.com/v1beta', recommendedModels: ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-1.0-pro']),
  ModelProvider(name: '阿里 / 通义千问', baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1', recommendedModels: ['qwen-max', 'qwen-plus', 'qwen-turbo', 'qwen-long']),
  ModelProvider(name: '百度 / 文心一言', baseUrl: 'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop', recommendedModels: ['ernie-4.0', 'ernie-3.5', 'ernie-speed']),
  ModelProvider(name: '讯飞 / 星火', baseUrl: 'https://spark-api-open.xf-yun.com/v1', recommendedModels: ['generalv3.5', 'generalv3', 'generalv2']),
  ModelProvider(name: '月之暗面 / Kimi', baseUrl: 'https://api.moonshot.cn/v1', recommendedModels: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k']),
  ModelProvider(name: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1', recommendedModels: ['deepseek-chat', 'deepseek-coder', 'deepseek-reasoner']),
  ModelProvider(name: '零一万物 / Yi', baseUrl: 'https://api.lingyiwanwu.com/v1', recommendedModels: ['yi-large', 'yi-medium', 'yi-spark']),
  ModelProvider(name: '阶跃星辰', baseUrl: 'https://api.stepfun.com/v1', recommendedModels: ['step-1-8k', 'step-1-32k', 'step-1-128k']),
  ModelProvider(name: 'MiniMax', baseUrl: 'https://api.minimax.chat/v1', recommendedModels: ['abab6.5s-chat', 'abab6.5-chat']),
  ModelProvider(name: '腾讯 / 混元', baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1', recommendedModels: ['hunyuan-lite', 'hunyuan-standard', 'hunyuan-pro']),
  ModelProvider(name: 'SiliconFlow / 硅基流动', baseUrl: 'https://api.siliconflow.cn/v1', recommendedModels: ['Qwen/Qwen2.5-72B-Instruct', 'deepseek-ai/DeepSeek-V2.5', 'meta-llama/Meta-Llama-3.1-405B-Instruct']),
  ModelProvider(name: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1', recommendedModels: ['openai/gpt-4o', 'anthropic/claude-3.5-sonnet', 'meta-llama/llama-3.1-405b-instruct']),
];

/// 视频模型提供商预设
const List<ModelProvider> _videoProviders = [
  ModelProvider(name: '自定义', baseUrl: ''),
  ModelProvider(name: '可灵 / Kling', baseUrl: 'https://api.klingai.com/v1', recommendedModels: ['kling-v1', 'kling-v1-5']),
  ModelProvider(name: '即梦 / Jimeng', baseUrl: 'https://api.jimeng.com/v1', recommendedModels: ['jimeng-v1']),
  ModelProvider(name: 'Runway', baseUrl: 'https://api.runwayml.com/v1', recommendedModels: ['gen-3-alpha-turbo', 'gen-2']),
  ModelProvider(name: 'Pika', baseUrl: 'https://api.pika.art/v1', recommendedModels: ['pika-1.0', 'pika-1.5']),
  ModelProvider(name: 'OpenAI / Sora', baseUrl: 'https://api.openai.com/v1', recommendedModels: ['sora']),
  ModelProvider(name: 'Vidu', baseUrl: 'https://api.vidu.cn/v1', recommendedModels: ['vidu-v1']),
  ModelProvider(name: 'Pixverse', baseUrl: 'https://api.pixverse.ai/v1', recommendedModels: ['pixverse-v1']),
  ModelProvider(name: '生数 / Vidu', baseUrl: 'https://api.vidu.studio/v1', recommendedModels: ['vidu-1.0']),
  ModelProvider(name: '海螺 / Hailuo', baseUrl: 'https://api.hailuoai.com/v1', recommendedModels: ['hailuo-v1']),
];

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

  late final TextEditingController _llmBaseUrlController;
  late final TextEditingController _llmModelController;
  late final TextEditingController _llmApiKeyController;
  late final TextEditingController _videoBaseUrlController;
  late final TextEditingController _videoModelController;
  late final TextEditingController _videoApiKeyController;
  late final TextEditingController _imageBaseUrlController;
  late final TextEditingController _imageModelController;
  late final TextEditingController _imageApiKeyController;

  String _selectedLlmProvider = '自定义';
  String _selectedVideoProvider = '自定义';

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

    _llmBaseUrlController = TextEditingController(text: _config.llmBaseUrl);
    _llmModelController = TextEditingController(text: _config.llmModel);
    _llmApiKeyController = TextEditingController(text: _config.llmApiKey);
    _videoBaseUrlController = TextEditingController(text: _config.videoBaseUrl);
    _videoModelController = TextEditingController(text: _config.videoModel);
    _videoApiKeyController = TextEditingController(text: _config.videoApiKey);
    _imageBaseUrlController = TextEditingController(text: _config.imageBaseUrl);
    _imageModelController = TextEditingController(text: _config.imageModel);
    _imageApiKeyController = TextEditingController(text: _config.imageApiKey);

    _selectedLlmProvider = _findProviderName(_llmProviders, _config.llmBaseUrl);
    _selectedVideoProvider = _findProviderName(_videoProviders, _config.videoBaseUrl);

    _initHeaderControllers();
  }

  String _findProviderName(List<ModelProvider> providers, String url) {
    for (final p in providers) {
      if (p.baseUrl.isNotEmpty && url == p.baseUrl) return p.name;
    }
    return '自定义';
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

  void _onLlmProviderChanged(String? name) {
    if (name == null) return;
    setState(() => _selectedLlmProvider = name);
    final provider = _llmProviders.firstWhere((p) => p.name == name);
    if (provider.baseUrl.isNotEmpty) {
      _llmBaseUrlController.text = provider.baseUrl;
    }
    if (_llmModelController.text.isEmpty && provider.recommendedModels.isNotEmpty) {
      _llmModelController.text = provider.recommendedModels.first;
    }
  }

  void _onVideoProviderChanged(String? name) {
    if (name == null) return;
    setState(() => _selectedVideoProvider = name);
    final provider = _videoProviders.firstWhere((p) => p.name == name);
    if (provider.baseUrl.isNotEmpty) {
      _videoBaseUrlController.text = provider.baseUrl;
    }
    if (_videoModelController.text.isEmpty && provider.recommendedModels.isNotEmpty) {
      _videoModelController.text = provider.recommendedModels.first;
    }
  }

  void _saveConfig() {
    _config.llmBaseUrl = _llmBaseUrlController.text.trim();
    _config.llmModel = _llmModelController.text.trim();
    _config.llmApiKey = _llmApiKeyController.text.trim();
    _config.videoBaseUrl = _videoBaseUrlController.text.trim();
    _config.videoModel = _videoModelController.text.trim();
    _config.videoApiKey = _videoApiKeyController.text.trim();
    _config.imageBaseUrl = _imageBaseUrlController.text.trim();
    _config.imageModel = _imageModelController.text.trim();
    _config.imageApiKey = _imageApiKeyController.text.trim();

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

  Widget _buildProviderDropdown({
    required List<ModelProvider> providers,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
          labelText: '选择提供商',
          prefixIcon: Icon(Icons.store),
          border: OutlineInputBorder(),
        ),
        items: providers.map((p) {
          return DropdownMenuItem<String>(
            value: p.name,
            child: Text(p.name),
          );
        }).toList(),
        onChanged: onChanged,
      ),
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

  Widget _buildModelSuggestions(List<String> models, TextEditingController controller) {
    if (models.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: models.map((m) {
          return ActionChip(
            label: Text(m, style: const TextStyle(fontSize: 12)),
            onPressed: () => controller.text = m,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLlmConfig() {
    final currentProvider = _llmProviders.firstWhere(
      (p) => p.name == _selectedLlmProvider,
      orElse: () => _llmProviders.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProviderDropdown(
            providers: _llmProviders,
            value: _selectedLlmProvider,
            onChanged: _onLlmProviderChanged,
          ),
          _buildSectionTitle('API 地址'),
          _buildInputField(
            controller: _llmBaseUrlController,
            hintText: 'https://api.example.com/v1',
            icon: Icons.link,
          ),
          _buildSectionTitle('模型名称'),
          _buildInputField(
            controller: _llmModelController,
            hintText: 'gpt-4o / glm-4 / claude-3-5-sonnet',
            icon: Icons.smart_toy,
          ),
          _buildModelSuggestions(currentProvider.recommendedModels, _llmModelController),
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

  Widget _buildVideoConfig() {
    final currentProvider = _videoProviders.firstWhere(
      (p) => p.name == _selectedVideoProvider,
      orElse: () => _videoProviders.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProviderDropdown(
            providers: _videoProviders,
            value: _selectedVideoProvider,
            onChanged: _onVideoProviderChanged,
          ),
          _buildSectionTitle('API 地址'),
          _buildInputField(
            controller: _videoBaseUrlController,
            hintText: 'https://api.example.com/v1',
            icon: Icons.link,
          ),
          _buildSectionTitle('模型名称'),
          _buildInputField(
            controller: _videoModelController,
            hintText: 'kling-v1 / sora / gen-3',
            icon: Icons.movie,
          ),
          _buildModelSuggestions(currentProvider.recommendedModels, _videoModelController),
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
