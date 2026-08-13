import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_config.dart';
import '../models/project.dart';

/// 本地存储服务
class StorageService {
  static const String _configKey = 'ai_config';
  static const String _projectsKey = 'projects';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // AI 配置
  static Future<AiConfig> loadConfig() async {
    final prefs = await _instance;
    final str = prefs.getString(_configKey);
    if (str != null && str.isNotEmpty) {
      return AiConfig.fromJsonString(str);
    }
    return AiConfig();
  }

  static Future<void> saveConfig(AiConfig config) async {
    final prefs = await _instance;
    await prefs.setString(_configKey, config.toJsonString());
  }

  // 项目列表
  static Future<List<ManjuProject>> loadProjects() async {
    final prefs = await _instance;
    final str = prefs.getString(_projectsKey);
    if (str != null && str.isNotEmpty) {
      final List<dynamic> list = jsonDecode(str);
      return list.map((e) => ManjuProject.fromJson(e)).toList();
    }
    return [];
  }

  static Future<void> saveProjects(List<ManjuProject> projects) async {
    final prefs = await _instance;
    final list = projects.map((p) => p.toJson()).toList();
    await prefs.setString(_projectsKey, jsonEncode(list));
  }

  static Future<void> saveProject(ManjuProject project) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    project.updatedAt = DateTime.now();
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.insert(0, project);
    }
    await saveProjects(projects);
  }

  static Future<void> deleteProject(String id) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == id);
    await saveProjects(projects);
  }
}
