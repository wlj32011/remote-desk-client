// 比邻远程手机版：远程（识别码 + 账号设备）、我的（账号、关于）。
// 「本机」页（安卓共享屏幕给电脑控制）沿用 server_page.dart。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/bilin_devices.dart';
import 'package:flutter_hbb/desktop/pages/bilin_home.dart';
import 'package:flutter_hbb/mobile/pages/bilin_update.dart';
import 'package:flutter_hbb/mobile/pages/home_page.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

// ================= 远程 =================

class BilinMobileRemotePage extends StatefulWidget implements PageShape {
  /// devices=false：“远程”页（输识别码、密码）；true：“设备”页（账号里的电脑）
  BilinMobileRemotePage({Key? key, this.devices = false})
      : title = devices ? '设备' : '远程',
        icon = Icon(devices ? Icons.devices_outlined : Icons.desktop_windows_outlined),
        super(key: key);

  final bool devices;

  @override
  final String title;

  @override
  final Widget icon;

  @override
  final List<Widget> appBarActions = const [];

  @override
  State<BilinMobileRemotePage> createState() => _BilinMobileRemotePageState();
}

class _BilinMobileRemotePageState extends State<BilinMobileRemotePage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _showPw = false;
  String _group = 'default';
  String _myId = '';
  final Map<String, bool> _online = {};
  static const _onlineHandler = 'bilin-mobile-onlines';
  Timer? _timer;
  Worker? _loginWorker;

  @override
  void initState() {
    super.initState();
    bind.mainGetMyId().then((v) => setState(() => _myId = v));
    if (!widget.devices) {
      // 安卓自动升级：打开后查一次，之后每小时查一次
      BilinAndroidUpdater.start();
      return;
    }
    platformFFI.registerEventHandler('callback_query_onlines', _onlineHandler,
        (evt) async {
      for (final id in '${evt['onlines'] ?? ''}'.split(',')) {
        if (id.isNotEmpty) _online[id] = true;
      }
      for (final id in '${evt['offlines'] ?? ''}'.split(',')) {
        if (id.isNotEmpty) _online[id] = false;
      }
      if (mounted) setState(() {});
    });
    _refresh();
    // 在「我的」页登录后，这里马上刷新设备和在线状态
    _loginWorker = ever(gFFI.userModel.userName, (v) {
      if ('$v'.isNotEmpty) _refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _queryOnline());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loginWorker?.dispose();
    if (widget.devices) {
      platformFFI.unregisterEventHandler('callback_query_onlines', _onlineHandler);
    }
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!gFFI.userModel.isLogin) return;
    await gFFI.abModel.pullAb(force: ForcePullAb.listAndCurrent, quiet: true);
    bilinSyncAccountDevices();
    _queryOnline();
  }

  void _queryOnline() {
    final ids = bilinAb()?.peers.map((p) => p.id).toList() ?? [];
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids);
  }

  List<String> get _tags =>
      bilinAb()?.tags.map((e) => '$e').toList() ?? <String>[];

  List<Peer> _peersOf(String group) {
    final all = (bilinAb()?.peers.toList() ?? <Peer>[])
        .where((p) => p.id != _myId)
        .toList();
    if (group == 'default') {
      final tags = _tags;
      return all.where((p) => !p.tags.any((t) => tags.contains(t))).toList();
    }
    return all.where((p) => p.tags.contains(group)).toList();
  }

  bool _isOn(Peer p) => _online[p.id] ?? p.online;

  void _connect() {
    final id = _id.text.replaceAll(RegExp(r'\s'), '');
    if (id.isEmpty) {
      showToast('请先输入对方的识别码');
      return;
    }
    FocusScope.of(context).unfocus();
    final pw = _pw.text.trim();
    bilinConnect(context, id, password: pw.isEmpty ? null : pw);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BilinColors.page(context),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (!widget.devices) ...[
              _connectCard(context),
              const SizedBox(height: 16),
              Text('对方电脑打开比邻远程后，把“本机识别码”和“临时密码”告诉你。'
                  '同一个账号下的电脑不用输密码，在“设备”里点一下就能连。',
                  style: TextStyle(fontSize: 13, height: 1.5, color: BilinColors.sub(context))),
            ] else
            Obx(() {
              // 订阅：登录状态、地址簿内容
              final login = gFFI.userModel.userName.value.isNotEmpty;
              gFFI.abModel.currentName.value;
              final ab = bilinAb();
              ab?.peers.length;
              ab?.tags.length;
              if (!login) return _loginHint(context);
              return _devices(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _connectCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BilinColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('控制远程设备',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: BilinColors.text(context))),
          const SizedBox(height: 14),
          TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _connect(),
            style: TextStyle(
                fontSize: 20,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: BilinColors.text(context)),
            decoration: InputDecoration(
              hintText: '输入对方识别码',
              hintStyle: TextStyle(
                  fontSize: 16,
                  letterSpacing: 0,
                  fontWeight: FontWeight.normal,
                  color: BilinColors.sub(context)),
              filled: true,
              fillColor: BilinColors.field(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            obscureText: !_showPw,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _connect(),
            style: TextStyle(fontSize: 16, color: BilinColors.text(context)),
            decoration: InputDecoration(
              hintText: '密码（同账号的电脑可不填）',
              hintStyle: TextStyle(fontSize: 15, color: BilinColors.sub(context)),
              filled: true,
              fillColor: BilinColors.field(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(_showPw
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () => setState(() => _showPw = !_showPw),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: BilinColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('远程控制',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BilinColors.border(context)),
      ),
      child: Column(children: [
        Icon(Icons.devices_other_outlined,
            size: 40, color: BilinColors.brand.withOpacity(0.8)),
        const SizedBox(height: 10),
        Text('登录后，账号里的电脑都会显示在这里，点一下就能连，不用输密码',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: BilinColors.sub(context))),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () async {
            await showBilinLoginDialog(context);
            _refresh();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: BilinColors.brand,
            side: const BorderSide(color: BilinColors.brand),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          ),
          child: const Text('登录 / 注册'),
        ),
      ]),
    );
  }

  Widget _devices(BuildContext context) {
    final tags = _tags;
    if (_group != 'default' && !tags.contains(_group)) _group = 'default';
    final peers = _peersOf(_group);
    final online = peers.where(_isOn).length;
    Widget chip(String key, String label) {
      final on = _group == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => setState(() => _group = key),
          selectedColor: BilinColors.brand,
          backgroundColor: BilinColors.card(context),
          side: BorderSide(
              color: on ? BilinColors.brand : BilinColors.border(context)),
          labelStyle: TextStyle(
              fontSize: 13,
              color: on ? Colors.white : BilinColors.text(context)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('我的设备',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: BilinColors.text(context))),
          const Spacer(),
          Text('在线 $online / ${peers.length}',
              style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('default', '默认分组'),
            for (final t in tags) chip(t, t),
          ]),
        ),
        const SizedBox(height: 10),
        if (peers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
                _group == 'default'
                    ? '这里还没有电脑。在电脑上装好比邻远程并登录同一个账号，就会出现在这里'
                    : '这个分组里还没有设备',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: BilinColors.sub(context))),
          )
        else
          for (final p in peers) _peerTile(context, p),
      ],
    );
  }

  Widget _peerTile(BuildContext context, Peer p) {
    final on = _isOn(p);
    final name = p.alias.isNotEmpty
        ? p.alias
        : (p.hostname.isNotEmpty ? p.hostname : groupId(p.id));
    final phone = p.platform.toLowerCase().contains('android') ||
        p.platform.toLowerCase().contains('ios');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => bilinConnect(context, p.id),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BilinColors.border(context)),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BilinColors.brand.withOpacity(on ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                    phone
                        ? Icons.phone_android_outlined
                        : Icons.desktop_windows_outlined,
                    size: 22,
                    color: on ? BilinColors.brand : BilinColors.sub(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: BilinColors.text(context))),
                    const SizedBox(height: 2),
                    Text(groupId(p.id),
                        style: TextStyle(
                            fontSize: 12, color: BilinColors.sub(context))),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? const Color(0xFF22C55E) : const Color(0xFFC5CBD6),
                ),
              ),
              const SizedBox(width: 6),
              Text(on ? '在线' : '离线',
                  style:
                      TextStyle(fontSize: 12, color: BilinColors.sub(context))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ================= 我的 =================

class BilinMobileMinePage extends StatefulWidget implements PageShape {
  BilinMobileMinePage({Key? key}) : super(key: key);

  @override
  final String title = '我的';

  @override
  final Widget icon = const Icon(Icons.person_outline);

  @override
  final List<Widget> appBarActions = const [];

  @override
  State<BilinMobileMinePage> createState() => _BilinMobileMinePageState();
}

class _BilinMobileMinePageState extends State<BilinMobileMinePage>
    with WidgetsBindingObserver {
  String _quality = (() {
    final v = bind.mainGetUserDefaultOption(key: 'image_quality');
    return ['best', 'balanced', 'low'].contains(v) ? v : 'balanced';
  })();

  String _version = '';
  String _myId = '';
  bool _ignoreBattery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    bind.mainGetVersion().then((v) => setState(() => _version = v));
    bind.mainGetMyId().then((v) => setState(() => _myId = v));
    _checkBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkBattery();
  }

  Future<void> _checkBattery() async {
    if (!isAndroid) return;
    final v = await AndroidPermissionManager.check(
        kRequestIgnoreBatteryOptimizations);
    if (mounted && v != _ignoreBattery) setState(() => _ignoreBattery = v);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BilinColors.page(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Obx(() => _account(context, gFFI.userModel.userName.value)),
          const SizedBox(height: 16),
          _section(context, [
            _tile(context, Icons.high_quality_outlined, '远程画质',
                sub: '流量少选“流畅”，看得清选“清晰”',
                trailing: DropdownButton<String>(
                  value: _quality,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'best', child: Text('清晰')),
                    DropdownMenuItem(value: 'balanced', child: Text('均衡')),
                    DropdownMenuItem(value: 'low', child: Text('流畅')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await bind.mainSetUserDefaultOption(
                        key: 'image_quality', value: v);
                    setState(() => _quality = v);
                  },
                )),
            if (isAndroid)
              InkWell(
                onTap: () => BilinAndroidUpdater.check(manual: true),
                child: _tile(context, Icons.system_update_outlined, '检查更新',
                    trailing: Icon(Icons.chevron_right,
                        color: BilinColors.sub(context))),
              ),
            _tile(context, Icons.info_outline, '版本',
                trailing: Text(_version,
                    style: TextStyle(
                        fontSize: 14, color: BilinColors.sub(context)))),
          ]),
          const SizedBox(height: 22),
          Center(
            child: Text('比邻远程 · 远方的电脑就在身边',
                style: TextStyle(fontSize: 12, color: BilinColors.sub(context))),
          ),
        ],
      ),
    );
  }

  Widget _account(BuildContext context, String user) {
    final login = user.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2B6CFF), Color(0xFF3F86FF), Color(0xFF1BB9AB)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(login ? user : '未登录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(login ? '账号下的电脑免密连接' : '登录后可同步设备、免密连接',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 13)),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            if (login) {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  content: const Text('确定退出登录吗？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('退出')),
                  ],
                ),
              );
              if (ok == true) await gFFI.userModel.logOut();
            } else {
              await showBilinLoginDialog(context);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(login ? '退出' : '登录'),
        ),
      ]),
    );
  }

  Widget _section(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BilinColors.border(context)),
      ),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
                height: 1,
                indent: 52,
                color: BilinColors.border(context)),
          children[i],
        ]
      ]),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      {String? sub, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Icon(icon, size: 22, color: BilinColors.brand),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      TextStyle(fontSize: 15, color: BilinColors.text(context))),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                        fontSize: 12, color: BilinColors.sub(context))),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }
}
