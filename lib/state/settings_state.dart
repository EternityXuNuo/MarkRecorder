import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用设置：WebDAV 备份配置等，持久化到 SharedPreferences。
class SettingsState extends ChangeNotifier {
  static const _kUrl = 'webdav_url';
  static const _kUser = 'webdav_user';
  static const _kPass = 'webdav_pass';
  static const _kLastBackup = 'webdav_last_backup';

  String webdavUrl = '';
  String webdavUser = '';
  String webdavPass = '';
  DateTime? lastBackup;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    webdavUrl = prefs.getString(_kUrl) ?? '';
    webdavUser = prefs.getString(_kUser) ?? '';
    webdavPass = prefs.getString(_kPass) ?? '';
    final last = prefs.getString(_kLastBackup);
    lastBackup = last == null ? null : DateTime.tryParse(last);
    notifyListeners();
  }

  bool get webdavConfigured => webdavUrl.trim().isNotEmpty;

  Future<void> saveWebdav({
    required String url,
    required String user,
    required String pass,
  }) async {
    webdavUrl = url.trim();
    webdavUser = user.trim();
    webdavPass = pass;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUrl, webdavUrl);
    await prefs.setString(_kUser, webdavUser);
    await prefs.setString(_kPass, webdavPass);
    notifyListeners();
  }

  Future<void> setLastBackup(DateTime time) async {
    lastBackup = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastBackup, time.toIso8601String());
    notifyListeners();
  }
}
