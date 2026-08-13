import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ai_config.dart';
import '../models/project.dart';
import '../services/storage_service.dart';
import 'project_screen.dart';

/// 首页 - 项目列表
class HomeScreen extends StatefulWidget {
  final AiConfig config;
  final Function() onOpenConfig;

  const HomeScreen({
    super.key,
    required this.config,
    required this.onOpenConfig,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ManjuProject> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await StorageService.loadProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _loading = false;
      });
    }
  }

  Future<void> _createNewProject() async {
    final project = ManjuProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新建漫剧 ${DateFormat('MM-dd HH:mm').format(DateTime.now())}',
    );
    await StorageService.saveProject(project);

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectScreen(
          config: widget.config,
          project: project,
        ),
      ),
    );
    if (result == true || mounted) {
      _loadProjects();
    }
  }

  Future<void> _openProject(ManjuProject project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectScreen(
          config: widget.config,
          project: project,
        ),
      ),
    );
    _loadProjects();
  }

  Future<void> _deleteProject(ManjuProject project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除"${project.title}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteProject(project.id);
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否已配置 AI
    final isConfigured = widget.config.llmApiKey.isNotEmpty && widget.config.llmBaseUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 漫剧生成器'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyState(context, isConfigured)
              : _buildProjectList(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewProject,
        icon: const Icon(Icons.add),
        label: const Text('新建漫剧'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isConfigured) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '开始创作你的漫剧',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '输入剧本，AI 自动生成分镜和视频',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (!isConfigured) ...[
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: widget.onOpenConfig,
                icon: const Icon(Icons.settings),
                label: const Text('先配置 AI 模型'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          final completedShots = project.shots.where((s) => s.isCompleted).length;

          return Dismissible(
            key: Key(project.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Theme.of(context).colorScheme.error,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteProject(project),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.movie,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      '${project.shots.length} 个镜头 · 已完成 $completedShots',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(project.updatedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openProject(project),
              ),
            ),
          );
        },
      ),
    );
  }
}
