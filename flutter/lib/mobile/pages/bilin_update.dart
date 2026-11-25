// 比邻远程安卓版自动升级：
// 打开 App 后和每隔一小时查一次 https://bilin.dccjin.cn/update/android.json，
// 有新版本就提示，点“立即更新”在 App 里下载，下载完拉起系统安装界面。
// 安卓不允许普通 App 静默安装，最后一步需要用户点“安装”。
// 第一次安装时系统会要求“允许来自此来源的应用”，用户去设置里打开后回到 App，会马上再提示一次。
// 签名由系统校验：只有同一把签名钥匙打的包才能覆盖安装。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class BilinAndroidUpdater {
  static const _json = 'https://bilin.dccjin.cn/update/android.json';
  static const _prefix = 'https://bilin.dccjin.cn/update/';
  static const _channel = MethodChannel('mChannel');
  static Timer? _timer;
  static bool _busy = false;
  // 这次打开 App 期间用户点过“以后再说”的版本，不再重复提示
  static String _dismissed = '';
  static DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);

  static void start() {
    if (!Platform.isAndroid || _timer != null) return;
    Future.delayed(const Duration(seconds: 8), check);
    _timer = Timer.periodic(const Duration(hours: 1), (_) => check());
    // 回到前台时也查（比如刚在设置里允许了安装、或者装到一半取消了）
    WidgetsBinding.instance.addObserver(_ResumeObserver());
  }

  static void _onResume() {
    if (DateTime.now().difference(_lastCheck) < const Duration(seconds: 30)) {
      return;
    }
    Future.delayed(const Duration(seconds: 2), check);
  }

  static List<int> _ver(String v) =>
      v.trim().split('.').map((x) => int.tryParse(x.trim()) ?? 0).toList();

  static bool _newer(String a, String b) {
    final x = _ver(a), y = _ver(b);
    for (var i = 0; i < 3; i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }

  static Future<void> check() async {
    if (_busy) return;
    // App 在后台、或者正被别人远程控制时不打扰
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (gFFI.serverModel.clients.isNotEmpty) return;
    _busy = true;
    _lastCheck = DateTime.now();
    try {
      final cur = await bind.mainGetVersion();
      if (cur.isEmpty || cur == '0.0.0') return;
      final resp = await http
          .get(Uri.parse('$_json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(resp.bodyBytes));
      final ver = '${j['version'] ?? ''}';
      final url = '${j['url'] ?? ''}';
      final size = (j['size'] is int) ? j['size'] as int : 0;
      if (ver.isEmpty || !url.startsWith(_prefix) || !url.endsWith('.apk')) {
        return;
      }
      if (!_newer(ver, cur) || ver == _dismissed) return;
      final ctx = globalKey.currentContext;
      if (ctx == null) return;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: const Text('发现新版本'),
          content: Text('比邻远程 $ver 已发布'
              '${size > 0 ? '（${(size / 1048576).toStringAsFixed(1)} MB）' : ''}，'
              '当前是 $cur。建议现在更新。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('以后再说')),
            ElevatedButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('立即更新')),
          ],
        ),
      );
      if (ok != true) {
        _dismissed = ver;
        return;
      }
      await _downloadAndInstall(ver, url, size);
    } catch (e) {
      debugPrint('bilin update: $e');
    } finally {
      _busy = false;
    }
  }

  static Future<void> _downloadAndInstall(
      String ver, String url, int size) async {
    final dir =
        Directory('${(await getTemporaryDirectory()).path}/bilin_update');
    final cached = File('${dir.path}/${url.substring(_prefix.length)}');
    if (size > 0 && await cached.exists() && await cached.length() == size) {
      await _install(cached, url);
      return;
    }
    final ctx = globalKey.currentContext;
    if (ctx == null) return;
    final progress = ValueNotifier<double>(0);
    var cancelled = false;
    final client = http.Client();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('正在下载 $ver'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v > 0 ? v : null),
              const SizedBox(height: 10),
              Text('${(v * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                cancelled = true;
                client.close();
                Navigator.of(c).pop();
              },
              child: const Text('取消')),
        ],
      ),
    );
    File? file;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      file = cached;
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) throw '下载失败（${resp.statusCode}）';
      final total = size > 0 ? size : (resp.contentLength ?? 0);
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) progress.value = got / total;
      }
      await sink.close();
      if (size > 0 && got != size) throw '下载不完整，请重试';
    } catch (e) {
      if (!cancelled) {
        final c = globalKey.currentContext;
        if (c != null) {
          Navigator.of(c).pop();
          showToast('$e');
        }
      }
      return;
    } finally {
      client.close();
    }
    if (cancelled) return;
    final c = globalKey.currentContext;
    if (c != null) Navigator.of(c).pop();
    await _install(file, url);
  }

  static Future<void> _install(File file, String url) async {
    bool started = false;
    try {
      started = await _channel.invokeMethod('bilin_install_apk', file.path) == true;
    } catch (e) {
      debugPrint('bilin update install: $e');
    }
    if (!started) {
      // 老系统（安卓 7 以下）App 内安装不了，交给浏览器下载
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) BilinAndroidUpdater._onResume();
  }
}
