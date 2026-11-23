// 比邻远程：设备列表页（参考连连控：左分组 + 右列表）和设置页（左分类 + 右详情，带返回键，在主窗口内打开）
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/bilin_home.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart'
    show setPasswordDialog;
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

// ================= 设备列表 =================

class BilinDevicesPage extends StatefulWidget {
  const BilinDevicesPage({Key? key}) : super(key: key);

  @override
  State<BilinDevicesPage> createState() => _BilinDevicesPageState();
}

class _BilinDevicesPageState extends State<BilinDevicesPage> {
  String _group = 'account'; // account = 我的设备（账号下）；recent = 最近连接
  String _filter = 'all'; // all / online / offline
  String _selected = '';
  final _search = TextEditingController();
  final Set<String> _queried = {};

  @override
  void initState() {
    super.initState();
    bind.mainLoadRecentPeers();
    if (gFFI.userModel.isLogin) {
      gFFI.groupModel.pull(force: true, quiet: true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _myId => gFFI.serverModel.serverId.text.replaceAll(' ', '');

  List<Peer> _peersOf(String group) => group == 'account'
      ? gFFI.groupModel.peersModel.peers
      : gFFI.recentPeersModel.peers;

  void _queryOnline(List<Peer> peers) {
    final ids = peers.map((p) => p.id).where((id) => id != _myId).toList();
    final key = ids.join(',');
    if (ids.isNotEmpty && !_queried.contains(key)) {
      _queried.add(key);
      bind.queryOnlines(ids: ids);
    }
  }

  int _onlineCount(List<Peer> peers) =>
      peers.where((p) => p.online || p.id == _myId).length;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [gFFI.groupModel.peersModel, gFFI.recentPeersModel]),
      builder: (context, _) {
        final account = _peersOf('account');
        final recent = _peersOf('recent');
        _queryOnline(account);
        _queryOnline(recent);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _left(context, account, recent),
            VerticalDivider(width: 1, color: BilinColors.border(context)),
            Expanded(child: _right(context)),
          ],
        );
      },
    );
  }

  Widget _left(BuildContext context, List<Peer> account, List<Peer> recent) {
    Widget group(String key, IconData icon, String name, List<Peer> peers) {
      final selected = _group == key;
      return Material(
        color: selected
            ? BilinColors.brand.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _group = key;
            _selected = '';
          }),
          child: SizedBox(
            height: 42,
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(icon,
                  size: 19,
                  color: selected ? BilinColors.brand : BilinColors.sub(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? BilinColors.brand
                            : BilinColors.text(context))),
              ),
              Text('${_onlineCount(peers)}/${peers.length}',
                  style: TextStyle(fontSize: 12, color: BilinColors.sub(context))),
              const SizedBox(width: 12),
            ]),
          ),
        ),
      );
    }

    return Container(
      width: 250,
      color: BilinColors.card(context),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索设备',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: BilinColors.field(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),
          Text('我的设备',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BilinColors.sub(context))),
          const SizedBox(height: 8),
          group('account', Icons.devices_outlined, '账号下的设备', account),
          const SizedBox(height: 4),
          group('recent', Icons.history, '最近连接', recent),
        ],
      ),
    );
  }

  Widget _right(BuildContext context) {
    final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
    if (_group == 'account' && !loggedIn) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.devices_outlined, size: 56, color: BilinColors.sub(context)),
          const SizedBox(height: 14),
          Text('登录账号后，用同一账号登录的电脑会自动出现在这里',
              style: TextStyle(fontSize: 14, color: BilinColors.sub(context))),
          const SizedBox(height: 18),
          SizedBox(
            width: 160,
            height: 44,
            child: ElevatedButton(
              onPressed: () => showBilinLoginDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: BilinColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('登录 / 注册', style: TextStyle(fontSize: 15)),
            ),
          ),
        ]),
      );
    }
    final all = _peersOf(_group);
    final kw = _search.text.trim().toLowerCase();
    final searched = all.where((p) {
      if (kw.isEmpty) return true;
      return p.id.contains(kw.replaceAll(' ', '')) ||
          p.alias.toLowerCase().contains(kw) ||
          p.hostname.toLowerCase().contains(kw);
    }).toList();
    bool isOn(Peer p) => p.online || p.id == _myId;
    final online = searched.where(isOn).length;
    final shown = searched.where((p) {
      if (_filter == 'online') return isOn(p);
      if (_filter == 'offline') return !isOn(p);
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.id == _myId) return -1;
        if (b.id == _myId) return 1;
        if (isOn(a) != isOn(b)) return isOn(a) ? -1 : 1;
        return _name(a).compareTo(_name(b));
      });

    Widget chip(String key, String label) {
      final sel = _filter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _filter = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? BilinColors.text(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: sel ? BilinColors.card(context) : BilinColors.sub(context))),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(_group == 'account' ? '账号下的设备' : '最近连接',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: BilinColors.text(context))),
            const Spacer(),
            if (_group == 'account')
              IconButton(
                tooltip: '刷新',
                onPressed: () {
                  _queried.clear();
                  gFFI.groupModel.pull(force: true, quiet: false);
                },
                icon: Icon(Icons.refresh_rounded, color: BilinColors.sub(context)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            chip('all', '全部 ${searched.length}'),
            chip('online', '在线 $online'),
            chip('offline', '离线 ${searched.length - online}'),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                        _group == 'account'
                            ? '没有设备。在别的电脑上安装比邻远程并登录同一账号，就会出现在这里'
                            : '还没有连接记录',
                        style: TextStyle(
                            fontSize: 14, color: BilinColors.sub(context))))
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _row(context, shown[i]),
                  ),
          ),
        ],
      ),
    );
  }

  String _name(Peer p) {
    if (p.alias.isNotEmpty) return p.alias;
    if (p.hostname.isNotEmpty) return p.hostname;
    return groupId(p.id);
  }

  Widget _tag(String text, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
      );

  Widget _row(BuildContext context, Peer p) {
    final isMe = p.id == _myId;
    final on = p.online || isMe;
    final sel = _selected == p.id;
    return Material(
      color: sel
          ? BilinColors.brand.withOpacity(BilinColors.isDark(context) ? 0.2 : 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selected = p.id),
        onDoubleTap: isMe ? null : () => connect(context, p.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                  BilinColors.text(context).withOpacity(0.75), BlendMode.srcIn),
              child: getPlatformImage(p.platform, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: BilinColors.text(context))),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (isMe)
                      _tag('本机', BilinColors.text(context), BilinColors.field(context))
                    else if (on)
                      _tag('在线', const Color(0xFF16A34A), const Color(0xFFDCFCE7))
                    else
                      _tag('离线', BilinColors.sub(context), BilinColors.field(context)),
                    Text(groupId(p.id),
                        style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
                  ]),
                ],
              ),
            ),
            if (sel && !isMe) ...[
              OutlinedButton(
                onPressed: () => connect(context, p.id, isFileTransfer: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BilinColors.brand,
                  side: const BorderSide(color: BilinColors.brand),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('文件传输'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => connect(context, p.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BilinColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('远程控制'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ================= 设置 =================

/// 当前设置分类：general / safety / display / audio / about
final RxString bilinSettingsSection = 'general'.obs;

class BilinSettingsPage extends StatelessWidget {
  final VoidCallback onBack;
  const BilinSettingsPage({Key? key, required this.onBack}) : super(key: key);

  static const _sections = [
    ['general', '通用', Icons.settings_outlined],
    ['safety', '安全', Icons.lock_outline],
    ['display', '画面', Icons.monitor_outlined],
    ['audio', '音频', Icons.volume_up_outlined],
    ['about', '关于', Icons.info_outline],
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 230,
          color: BilinColors.card(context),
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          child: Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text('设置',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: BilinColors.text(context))),
                  ),
                  for (final s in _sections)
                    _item(context, s[0] as String, s[1] as String,
                        s[2] as IconData),
                ],
              )),
        ),
        VerticalDivider(width: 1, color: BilinColors.border(context)),
        Expanded(
          child: Obx(() {
            final key = bilinSettingsSection.value;
            final title =
                _sections.firstWhere((s) => s[0] == key)[1] as String;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 60,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(
                      left: 14,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: onBack,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: BilinColors.border(context)),
                            color: BilinColors.card(context),
                          ),
                          child: Icon(Icons.chevron_left,
                              color: BilinColors.text(context)),
                        ),
                      ),
                    ),
                    Text(title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: BilinColors.text(context))),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                    children: [
                      if (key == 'general') const _GeneralSettings(),
                      if (key == 'safety') const _SafetySettings(),
                      if (key == 'display') const _DisplaySettings(),
                      if (key == 'audio') const _AudioSettings(),
                      if (key == 'about') const _AboutSettings(),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _item(BuildContext context, String key, String name, IconData icon) {
    final sel = bilinSettingsSection.value == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: sel ? BilinColors.brand.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => bilinSettingsSection.value = key,
          child: SizedBox(
            height: 44,
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(icon,
                  size: 20, color: sel ? BilinColors.brand : BilinColors.sub(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel ? BilinColors.brand : BilinColors.text(context))),
              ),
              Icon(Icons.chevron_right, size: 18, color: BilinColors.sub(context)),
              const SizedBox(width: 8),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 一组设置（小标题 + 白色圆角块）
Widget _group(BuildContext context, String? title, List<Widget> rows) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title,
                style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
          ),
        Container(
          decoration: BoxDecoration(
            color: BilinColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BilinColors.border(context)),
          ),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 16, color: BilinColors.border(context)),
              rows[i],
            ]
          ]),
        ),
      ],
    ),
  );
}

/// 一行设置：左名称（可带说明），右控件
Widget _row(BuildContext context, String label, Widget trailing,
    {String? desc}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    child: Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 15, color: BilinColors.text(context))),
            if (desc != null) ...[
              const SizedBox(height: 3),
              Text(desc,
                  style: TextStyle(fontSize: 12.5, color: BilinColors.sub(context))),
            ],
          ],
        ),
      ),
      trailing,
    ]),
  );
}

Widget _dropdown(BuildContext context, String value, Map<String, String> items,
    ValueChanged<String> onChanged) {
  if (!items.containsKey(value)) value = items.keys.first;
  return DropdownButton<String>(
    value: value,
    underline: const SizedBox(),
    borderRadius: BorderRadius.circular(10),
    style: TextStyle(fontSize: 14, color: BilinColors.text(context)),
    items: [
      for (final e in items.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

Widget _switch(bool value, ValueChanged<bool>? onChanged) => Switch(
      value: value,
      onChanged: onChanged,
      activeColor: BilinColors.brand,
    );

class _GeneralSettings extends StatefulWidget {
  const _GeneralSettings();
  @override
  State<_GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<_GeneralSettings> {
  @override
  Widget build(BuildContext context) {
    final lang = bind.mainGetLocalOption(key: kCommConfKeyLang);
    final theme = MyTheme.getThemeModePreference();
    final installed = bind.mainIsInstalled();
    final serviceStopped =
        bind.mainGetOptionSync(key: kOptionStopService) == 'Y';
    final keepAwake = option2bool(kOptionKeepAwakeDuringIncomingSessions,
        bind.mainGetOptionSync(key: kOptionKeepAwakeDuringIncomingSessions));
    return Column(children: [
      _group(context, null, [
        _row(
            context,
            '语言',
            _dropdown(context, lang, const {
              '': '跟随系统',
              'zh-cn': '简体中文',
              'zh-tw': '繁體中文',
              'en': 'English',
            }, (v) async {
              await bind.mainSetLocalOption(key: kCommConfKeyLang, value: v);
              reloadAllWindows();
              bind.mainChangeLanguage(lang: v);
              setState(() {});
            })),
        _row(
            context,
            '主题',
            _dropdown(
                context,
                theme == ThemeMode.light
                    ? 'light'
                    : theme == ThemeMode.dark
                        ? 'dark'
                        : 'system',
                const {'system': '自动', 'light': '明亮', 'dark': '黑暗'},
                (v) async {
              await MyTheme.changeDarkMode(v == 'light'
                  ? ThemeMode.light
                  : v == 'dark'
                      ? ThemeMode.dark
                      : ThemeMode.system);
              setState(() {});
            })),
      ]),
      _group(context, null, [
        _row(
          context,
          '开机自动启动',
          _switch(
              installed && !serviceStopped,
              installed
                  ? (v) async {
                      await start_service(v);
                      setState(() {});
                    }
                  : null),
          desc: installed
              ? 'Windows 启动后自动运行比邻远程，别人随时可以连上这台电脑'
              : '需要先安装比邻远程（主页上方的“安装”提示）才能开机自启',
        ),
        _row(
          context,
          '阻止本机休眠',
          _switch(keepAwake, (v) async {
            await bind.mainSetOption(
                key: kOptionKeepAwakeDuringIncomingSessions,
                value: v ? 'Y' : 'N');
            setState(() {});
          }),
          desc: '被远程控制期间不让电脑进入休眠',
        ),
      ]),
    ]);
  }
}

class _SafetySettings extends StatefulWidget {
  const _SafetySettings();
  @override
  State<_SafetySettings> createState() => _SafetySettingsState();
}

class _SafetySettingsState extends State<_SafetySettings> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, model, _) {
        return Column(children: [
          _group(context, '访问密码', [
            _row(
              context,
              '密码方式',
              _dropdown(context, model.verificationMethod, const {
                kUseBothPasswords: '临时密码和固定密码都可以',
                kUseTemporaryPassword: '只用临时密码',
                kUsePermanentPassword: '只用固定密码',
              }, (v) => model.setVerificationMethod(v)),
              desc: '临时密码每次重启会变；固定密码适合无人值守的电脑',
            ),
            _row(
              context,
              '固定密码',
              OutlinedButton(
                onPressed: () => setPasswordDialog(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BilinColors.brand,
                  side: const BorderSide(color: BilinColors.brand),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('设置'),
              ),
              desc: '设置后，知道这个密码的人可以随时连这台电脑',
            ),
          ]),
        ]);
      }),
    );
  }
}

class _DisplaySettings extends StatefulWidget {
  const _DisplaySettings();
  @override
  State<_DisplaySettings> createState() => _DisplaySettingsState();
}

class _DisplaySettingsState extends State<_DisplaySettings> {
  String _get(String k) => bind.mainGetUserDefaultOption(key: k);
  Future<void> _set(String k, String v) async {
    await bind.mainSetUserDefaultOption(key: k, value: v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fps = _get('custom-fps');
    final quality = _get(kOptionImageQuality);
    final view = _get(kOptionViewStyle);
    final i444 = _get(kOptionI444) == 'Y';
    Widget seg(String value, String label) {
      final sel = (view.isEmpty ? kRemoteViewStyleAdaptive : view) == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _set(kOptionViewStyle, value),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? BilinColors.card(context) : BilinColors.field(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? BilinColors.brand : Colors.transparent, width: 1.2),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? BilinColors.brand : BilinColors.sub(context))),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _group(context, '远程画面（控制别人时）', [
        _row(
            context,
            '刷新率',
            _dropdown(context, fps.isEmpty ? '30' : fps,
                const {'30': '30 帧', '60': '60 帧'}, (v) => _set('custom-fps', v))),
        _row(
            context,
            '画质',
            _dropdown(
                context,
                quality.isEmpty ? kRemoteImageQualityBalanced : quality,
                const {
                  kRemoteImageQualityBest: '画质优先',
                  kRemoteImageQualityBalanced: '均衡',
                  kRemoteImageQualityLow: '流畅优先',
                },
                (v) => _set(kOptionImageQuality, v))),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('画面适配',
            style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
      ),
      Row(children: [
        seg(kRemoteViewStyleAdaptive, '自动适应窗口'),
        const SizedBox(width: 10),
        seg(kRemoteViewStyleOriginal, '原始大小'),
      ]),
      const SizedBox(height: 18),
      _group(context, '高级', [
        _row(context, 'YUV 4:4:4 色彩',
            _switch(i444, (v) => _set(kOptionI444, v ? 'Y' : '')),
            desc: '颜色更准、文字更清楚，但更占网速'),
      ]),
    ]);
  }
}

class _AudioSettings extends StatefulWidget {
  const _AudioSettings();
  @override
  State<_AudioSettings> createState() => _AudioSettingsState();
}

class _AudioSettingsState extends State<_AudioSettings> {
  @override
  Widget build(BuildContext context) {
    final disabled =
        bind.mainGetUserDefaultOption(key: kOptionDisableAudio) == 'Y';
    return _group(context, '音频选项', [
      _row(
        context,
        '远程音频',
        _switch(!disabled, (v) async {
          await bind.mainSetUserDefaultOption(
              key: kOptionDisableAudio, value: v ? 'N' : 'Y');
          setState(() {});
        }),
        desc: '控制别人时，播放对方电脑的声音',
      ),
    ]);
  }
}

class _AboutSettings extends StatelessWidget {
  const _AboutSettings();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: bind.mainGetVersion(),
      builder: (context, snap) => Column(children: [
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset('assets/icon.png', width: 72, height: 72),
        ),
        const SizedBox(height: 12),
        Text('比邻远程',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: BilinColors.text(context))),
        const SizedBox(height: 6),
        Text('版本 ${snap.data ?? ''}',
            style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
        const SizedBox(height: 24),
        Text(
            '比邻远程基于 RustDesk 开源项目修改（AGPL-3.0）\nRustDesk Copyright © Purslane Tech Pte. Ltd.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: BilinColors.sub(context))),
      ]),
    );
  }
}
