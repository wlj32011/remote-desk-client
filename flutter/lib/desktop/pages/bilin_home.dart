// 比邻远程：桌面版主页（11-23 用户选定 Codex 设计稿“方案 A 明亮简约”）
// 左侧导航：品牌名、远程协助、设备列表，底部设置；
// 「远程协助」：左卡片“允许控制本机”（识别码 + 临时密码），右卡片“控制远程设备”（输入识别码 + 两个按钮），
// 下面一排“最近连接”设备卡片；底部状态栏。只用公开 API（gFFI / bind / connect），不改 RustDesk 的连接逻辑。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart'
    show OnlineStatusWidget;
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class BilinColors {
  static const brand = Color(0xFF1E66FF);
  static const teal = Color(0xFF1ED6B5);
  static const online = Color(0xFF22C55E);
  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;
  static Color page(BuildContext c) =>
      isDark(c) ? const Color(0xFF1B1D22) : const Color(0xFFF5F7FB);
  static Color sidebar(BuildContext c) =>
      isDark(c) ? const Color(0xFF16181C) : const Color(0xFFF0F3F9);
  static Color card(BuildContext c) =>
      isDark(c) ? const Color(0xFF24272E) : Colors.white;
  static Color field(BuildContext c) =>
      isDark(c) ? const Color(0xFF2A3346) : const Color(0xFFEDF3FE);
  static Color border(BuildContext c) =>
      isDark(c) ? const Color(0xFF33373F) : const Color(0xFFE3E8F0);
  static Color inputBorder(BuildContext c) =>
      isDark(c) ? const Color(0xFF3B4150) : const Color(0xFFCFD6E2);
  static Color text(BuildContext c) =>
      isDark(c) ? const Color(0xFFF2F3F5) : const Color(0xFF111827);
  static Color sub(BuildContext c) =>
      isDark(c) ? const Color(0xFF9AA0AA) : const Color(0xFF6B7280);
}

/// 标题前的品牌色小竖条
Widget bilinTitle(BuildContext context, String text, {double size = 20}) {
  return Row(
    children: [
      Container(
        width: 4,
        height: size * 1.05,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            colors: [BilinColors.brand, BilinColors.teal],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(text,
          style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: BilinColors.text(context))),
    ],
  );
}

/// 主页整体：左导航 + 内容区。[notice] 是 RustDesk 原有的安装/权限/更新提示卡片，原样放在内容区顶部。
class BilinHome extends StatefulWidget {
  final Widget? notice;
  const BilinHome({Key? key, this.notice}) : super(key: key);

  @override
  State<BilinHome> createState() => _BilinHomeState();
}

class _BilinHomeState extends State<BilinHome> {
  final RxInt _nav = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BilinColors.page(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Obx(() => IndexedStack(
                        index: _nav.value,
                        children: [
                          _AssistPage(
                              notice: widget.notice,
                              onShowAll: () => _nav.value = 1),
                          const _DevicesPage(),
                        ],
                      )),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: BilinColors.card(context),
                    border: Border(
                        top: BorderSide(color: BilinColors.border(context))),
                  ),
                  child: OnlineStatusWidget(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 188,
      color: BilinColors.sidebar(context),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/icon.png', width: 30, height: 30),
              ),
              const SizedBox(width: 10),
              Text('比邻远程',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: BilinColors.text(context))),
            ],
          ).paddingOnly(left: 6, bottom: 22),
          _navItem(context, 0, Icons.desktop_windows_outlined, '远程协助'),
          const SizedBox(height: 6),
          _navItem(context, 1, Icons.devices_outlined, '设备列表'),
          const Spacer(),
          _sideButton(context, Icons.settings_outlined, '设置', () {
            if (DesktopSettingPage.tabKeys.isNotEmpty) {
              DesktopSettingPage.switch2page(DesktopSettingPage.tabKeys[0]);
            } else {
              DesktopTabPage.onAddSetting();
            }
          }),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    return Obx(() => _sideButton(context, icon, label, () => _nav.value = index,
        selected: _nav.value == index));
  }

  Widget _sideButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool selected = false}) {
    final color = selected ? BilinColors.brand : BilinColors.text(context);
    return Material(
      color: selected
          ? BilinColors.brand
              .withOpacity(BilinColors.isDark(context) ? 0.22 : 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: color,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 白色圆角卡片
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card(
      {required this.child,
      this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BilinColors.border(context)),
        boxShadow: BilinColors.isDark(context)
            ? null
            : [
                BoxShadow(
                    color: const Color(0xFF1F2937).withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
      ),
      child: child,
    );
  }
}

/// 「远程协助」页
class _AssistPage extends StatelessWidget {
  final Widget? notice;
  final VoidCallback onShowAll;
  const _AssistPage({this.notice, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) notice!,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Expanded(child: _LocalCard()),
                SizedBox(width: 18),
                Expanded(child: _RemoteCard()),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _RecentRow(onShowAll: onShowAll),
        ],
      ),
    );
  }
}

/// 左卡片：允许控制本机
class _LocalCard extends StatelessWidget {
  const _LocalCard();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, model, _) {
        final showOneTime = model.approveMode != 'click' &&
            model.verificationMethod != kUsePermanentPassword;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bilinTitle(context, '允许控制本机'),
              const SizedBox(height: 18),
              _InfoField(
                label: '本机识别码',
                listenable: model.serverId,
                value: () => groupId(model.serverId.text),
                copyText: () => model.serverId.text,
                big: true,
              ),
              const SizedBox(height: 12),
              _PasswordField(model: model, showOneTime: showOneTime),
            ],
          ),
        );
      }),
    );
  }
}

/// 识别码三位一组：218181697 -> 218 181 697
String groupId(String id) {
  final s = id.replaceAll(' ', '');
  if (s.isEmpty) return '…';
  if (int.tryParse(s) == null) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.tip, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 21, color: BilinColors.sub(context)),
        ),
      ),
    );
  }
}

Widget _fieldBox(BuildContext context, {required Widget child}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
    decoration: BoxDecoration(
      color: BilinColors.field(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _InfoField extends StatelessWidget {
  final String label;
  final Listenable listenable;
  final String Function() value;
  final String Function() copyText;
  final bool big;
  const _InfoField(
      {required this.label,
      required this.listenable,
      required this.value,
      required this.copyText,
      this.big = false});

  @override
  Widget build(BuildContext context) {
    return _fieldBox(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: listenable,
                  builder: (context, _) => SelectableText(
                    value(),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: big ? 32 : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: BilinColors.text(context),
                    ),
                  ),
                ),
              ),
              _IconBtn(Icons.copy_rounded, '复制', () {
                Clipboard.setData(ClipboardData(text: copyText()));
                showToast(translate('Copied'));
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final ServerModel model;
  final bool showOneTime;
  const _PasswordField({required this.model, required this.showOneTime});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return _fieldBox(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.showOneTime ? '临时密码' : '访问密码',
              style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: model.serverPasswd,
                  builder: (context, _) {
                    final pwd = model.serverPasswd.text;
                    final shown = widget.showOneTime
                        ? (_visible ? pwd : '••••••')
                        : '已设置固定密码';
                    return SelectableText(
                      shown.isEmpty ? '-' : shown,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: widget.showOneTime ? 28 : 15,
                        fontWeight: widget.showOneTime
                            ? FontWeight.w800
                            : FontWeight.normal,
                        letterSpacing: widget.showOneTime ? 1.2 : 0,
                        color: BilinColors.text(context),
                      ),
                    );
                  },
                ),
              ),
              if (widget.showOneTime) ...[
                _IconBtn(
                    _visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    _visible ? '隐藏' : '显示',
                    () => setState(() => _visible = !_visible)),
                _IconBtn(Icons.sync_rounded, '换一个密码',
                    () => bind.mainUpdateTemporaryPassword()),
                _IconBtn(Icons.copy_rounded, '复制', () {
                  Clipboard.setData(
                      ClipboardData(text: model.serverPasswd.text));
                  showToast(translate('Copied'));
                }),
              ],
              if (!widget.showOneTime && !bind.isDisableSettings())
                _IconBtn(Icons.edit_outlined, '修改密码',
                    () => DesktopSettingPage.switch2page(SettingsTabKey.safety)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 右卡片：控制远程设备
class _RemoteCard extends StatefulWidget {
  const _RemoteCard();

  @override
  State<_RemoteCard> createState() => _RemoteCardState();
}

class _RemoteCardState extends State<_RemoteCard> {
  final _idCtrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _idCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _id => _idCtrl.text.replaceAll(' ', '');

  void _go({bool file = false}) {
    if (_id.isEmpty) {
      _focus.requestFocus();
      showToast('请先输入对方的识别码');
      return;
    }
    connect(context, _id, isFileTransfer: file);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bilinTitle(context, '控制远程设备'),
          const Spacer(),
          TextField(
            controller: _idCtrl,
            focusNode: _focus,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [IDTextInputFormatter()],
            onSubmitted: (_) => _go(),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: BilinColors.text(context)),
            decoration: InputDecoration(
              hintText: '输入对方识别码',
              hintStyle: TextStyle(
                  fontSize: 17,
                  letterSpacing: 0,
                  fontWeight: FontWeight.normal,
                  color: BilinColors.sub(context)),
              filled: true,
              fillColor: BilinColors.card(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              border: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide:
                      BorderSide(color: BilinColors.inputBorder(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(
                      color: BilinColors.inputBorder(context), width: 1.2)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide:
                      const BorderSide(color: BilinColors.brand, width: 1.6)),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _go(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BilinColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: radius),
                    ),
                    child: const Text('远程控制',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _go(file: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BilinColors.brand,
                      backgroundColor: BilinColors.card(context),
                      side: const BorderSide(
                          color: BilinColors.brand, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: radius),
                    ),
                    child: const Text('文件传输',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// 最近连接：一排设备卡片（最多 4 台），点卡片直接连
class _RecentRow extends StatefulWidget {
  final VoidCallback onShowAll;
  const _RecentRow({required this.onShowAll});

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  @override
  void initState() {
    super.initState();
    bind.mainLoadRecentPeers();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.recentPeersModel,
      child: Consumer<Peers>(builder: (context, model, _) {
        final peers = model.peers.take(4).toList();
        if (peers.isNotEmpty && model.event == UpdateEvent.load) {
          bind.queryOnlines(ids: peers.map((p) => p.id).toList());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                bilinTitle(context, '最近连接', size: 19),
                const Spacer(),
                TextButton(
                  onPressed: widget.onShowAll,
                  child: const Text('查看全部',
                      style: TextStyle(color: BilinColors.brand)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (peers.isEmpty)
              _Card(
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Center(
                  child: Text('还没有连接过的设备，输入对方识别码开始第一次远程吧',
                      style: TextStyle(
                          fontSize: 14, color: BilinColors.sub(context))),
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(
                        child: i < peers.length
                            ? _PeerCard(peer: peers[i])
                            : const SizedBox()),
                  ],
                ],
              ),
          ],
        );
      }),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final Peer peer;
  const _PeerCard({required this.peer});

  String get _name {
    if (peer.alias.isNotEmpty) return peer.alias;
    if (peer.hostname.isNotEmpty) return peer.hostname;
    return groupId(peer.id);
  }

  IconData get _icon {
    final p = peer.platform.toLowerCase();
    if (p.contains('android') || p.contains('ios')) {
      return Icons.smartphone_outlined;
    }
    if (p.contains('mac')) return Icons.laptop_mac_outlined;
    return Icons.desktop_windows_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => connect(context, peer.id),
        child: _Card(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            children: [
              Icon(_icon, size: 44, color: BilinColors.sub(context)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BilinColors.text(context))),
                    const SizedBox(height: 4),
                    Text(groupId(peer.id),
                        style: TextStyle(
                            fontSize: 14, color: BilinColors.sub(context))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: peer.online
                                ? BilinColors.online
                                : const Color(0xFFB8BEC8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(peer.online ? '在线' : '离线',
                            style: TextStyle(
                                fontSize: 13,
                                color: BilinColors.sub(context))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「设备列表」页：最近连接、收藏、地址簿（沿用 RustDesk 的列表组件）
class _DevicesPage extends StatelessWidget {
  const _DevicesPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bilinTitle(context, '设备列表'),
          const SizedBox(height: 14),
          const Expanded(
            child: _Card(
              padding: EdgeInsets.fromLTRB(14, 8, 4, 4),
              child: PeerTabPage(),
            ),
          ),
        ],
      ),
    );
  }
}
