// 比邻远程：桌面版主页（11-23 用户选定 Codex 设计稿“方案 A 明亮简约”）
// 左侧导航：品牌名、远程协助、设备列表，底部设置；
// 「远程协助」：左卡片“允许控制本机”（识别码 + 临时密码），右卡片“控制远程设备”（输入识别码 + 两个按钮），
// 下面一排“最近连接”设备卡片；底部状态栏。只用公开 API（gFFI / bind / connect），不改 RustDesk 的连接逻辑。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart'
    show OnlineStatusWidget;
import 'package:flutter_hbb/desktop/pages/bilin_pages.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:http/http.dart' as http;
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

/// 当前页：0 远程协助，1 设备列表，2 设置
final RxInt bilinNav = 0.obs;

/// 主页整体：左导航 + 内容区。[notice] 是 RustDesk 原有的安装/权限/更新提示卡片，原样放在内容区顶部。
class BilinHome extends StatefulWidget {
  final Widget? notice;
  const BilinHome({Key? key, this.notice}) : super(key: key);

  @override
  State<BilinHome> createState() => _BilinHomeState();
}

class _BilinHomeState extends State<BilinHome> {

  @override
  void initState() {
    super.initState();
    bilinLoadMode();
    // 仅被控模式下回到“远程协助”页
    ever(bilinMode, (_) {
      if (bilinMode.value == 'incoming' && bilinNav.value == 1) {
        bilinNav.value = 0;
      }
    });
  }

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
                        index: bilinNav.value,
                        children: [
                          _AssistPage(
                              notice: widget.notice,
                              onShowAll: () => bilinNav.value = 1),
                          const BilinDevicesPage(),
                          BilinSettingsPage(onBack: () => bilinNav.value = 0),
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
          Obx(() => bilinMode.value == 'incoming'
              ? const SizedBox()
              : _navItem(context, 1, Icons.devices_outlined, '设备列表')),
          const Spacer(),
          const _AccountButton(),
          const SizedBox(height: 4),
          _navItem(context, 2, Icons.settings_outlined, '设置'),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    return Obx(() => _sideButton(context, icon, label, () => bilinNav.value = index,
        selected: bilinNav.value == index));
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
class BilinCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const BilinCard(
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
          Obx(() => bilinMode.value == 'incoming'
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LocalCard(),
                        const SizedBox(height: 14),
                        Text('当前为“仅被控”模式：本机只允许被远程控制。可在左下角账号菜单里切换。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: BilinColors.sub(context))),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                )),
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
        return BilinCard(
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
                _IconBtn(Icons.edit_outlined, '修改密码', () {
                  bilinSettingsSection.value = 'safety';
                  bilinNav.value = 2;
                }),
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
    return BilinCard(
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
              BilinCard(
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
        child: BilinCard(
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

// ===== 账号：登录 / 注册 / 模式 =====

/// 'both' = 主控 + 被控；'incoming' = 仅被控
final RxString bilinMode = 'both'.obs;
const _kBilinModeKey = 'bilin-mode';

void bilinLoadMode() {
  final v = bind.mainGetLocalOption(key: _kBilinModeKey);
  bilinMode.value = v == 'incoming' ? 'incoming' : 'both';
}

Future<void> bilinSetMode(String mode) async {
  bilinMode.value = mode;
  await bind.mainSetLocalOption(key: _kBilinModeKey, value: mode);
}

String bilinModeLabel(String mode) => mode == 'incoming' ? '仅被控' : '主控 + 被控';

/// 侧栏底部的账号入口
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final name = gFFI.userModel.userName.value;
      if (name.isEmpty) {
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showBilinLoginDialog(context),
            child: SizedBox(
              height: 46,
              child: Row(children: [
                const SizedBox(width: 14),
                Icon(Icons.account_circle_outlined,
                    size: 21, color: BilinColors.text(context)),
                const SizedBox(width: 12),
                Text('登录 / 注册',
                    style: TextStyle(
                        fontSize: 15, color: BilinColors.text(context))),
              ]),
            ),
          ),
        );
      }
      return PopupMenuButton<String>(
        tooltip: '账号',
        offset: const Offset(0, -110),
        onSelected: (v) async {
          if (v == 'mode') {
            await bilinSetMode(
                bilinMode.value == 'incoming' ? 'both' : 'incoming');
            showToast('已切换为“${bilinModeLabel(bilinMode.value)}”');
          } else if (v == 'logout') {
            await gFFI.userModel.logOut();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'mode',
              child: Text(bilinMode.value == 'incoming'
                  ? '切换为“主控 + 被控”'
                  : '切换为“仅被控”')),
          const PopupMenuItem(value: 'logout', child: Text('退出登录')),
        ],
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: BilinColors.brand,
              child: Text(name.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BilinColors.text(context))),
                  Text(bilinModeLabel(bilinMode.value),
                      style: TextStyle(
                          fontSize: 12, color: BilinColors.sub(context))),
                ],
              ),
            ),
          ]),
        ),
      );
    });
  }
}

Future<void> showBilinLoginDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _LoginDialog(),
  );
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  bool _register = false;
  bool _busy = false;
  String _error = '';
  String _mode = bilinMode.value;
  final _user = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _user.text.trim();
    final pwd = _pwd.text;
    if (user.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    if (_register) {
      if (pwd.length < 6) {
        setState(() => _error = '密码至少 6 位');
        return;
      }
      if (pwd != _pwd2.text) {
        setState(() => _error = '两次输入的密码不一样');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_register) {
        final api = await bind.mainGetApiServer();
        final resp = await http.post(
          Uri.parse('$api/api/admin/user/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': user,
            'password': pwd,
            'confirm_password': pwd,
          }),
        );
        final body = jsonDecode(decode_http_response(resp));
        if (body is! Map || body['code'] != 0) {
          final msg = body is Map ? (body['message'] ?? '') : '';
          throw Exception(msg == '操作失败。' ? '这个账号已被注册，换一个试试' : '注册失败：$msg');
        }
      }
      final resp = await gFFI.userModel.login(LoginRequest(
          username: user,
          password: pwd,
          id: await bind.mainGetMyId(),
          uuid: await bind.mainGetUuid(),
          autoLogin: true,
          type: HttpType.kAuthReqTypeAccount));
      if (resp.type == HttpType.kAuthResTypeToken &&
          resp.access_token != null) {
        await bind.mainSetLocalOption(
            key: 'access_token', value: resp.access_token!);
        await bind.mainSetLocalOption(
            key: 'user_info', value: jsonEncode(resp.user ?? {}));
        await bilinSetMode(_mode);
        gFFI.groupModel.pull(force: true, quiet: true);
        if (mounted) Navigator.of(context).pop();
        showToast(_register ? '注册成功，已登录' : '登录成功');
        return;
      }
      setState(() => _error = '登录失败，请稍后再试');
    } on RequestException catch (e) {
      setState(() => _error = e.cause.contains('密码') || e.cause.isEmpty
          ? '账号或密码不对'
          : e.cause);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: BilinColors.field(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );

  Widget _modeOption(String value, String title, String desc) {
    final selected = _mode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _mode = value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? BilinColors.brand : BilinColors.border(context),
                width: selected ? 1.6 : 1),
            color: selected ? BilinColors.brand.withOpacity(0.06) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: selected ? BilinColors.brand : BilinColors.sub(context)),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BilinColors.text(context))),
              ]),
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(fontSize: 12, color: BilinColors.sub(context))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BilinColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/icon.png', width: 30, height: 30),
                ),
                const SizedBox(width: 10),
                Text(_register ? '注册比邻远程账号' : '登录比邻远程',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: BilinColors.text(context))),
              ]),
              const SizedBox(height: 20),
              TextField(
                controller: _user,
                autofocus: true,
                decoration: _deco('账号（手机号或用户名）', Icons.person_outline),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pwd,
                obscureText: true,
                onSubmitted: (_) => _register ? null : _submit(),
                decoration: _deco('密码', Icons.lock_outline),
              ),
              if (_register) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _pwd2,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: _deco('再输一次密码', Icons.lock_outline),
                ),
              ],
              const SizedBox(height: 18),
              Text('这台电脑的使用方式',
                  style: TextStyle(fontSize: 13, color: BilinColors.sub(context))),
              const SizedBox(height: 8),
              Row(children: [
                _modeOption('both', '主控 + 被控', '能控制别人，也能被控制'),
                const SizedBox(width: 10),
                _modeOption('incoming', '仅被控', '只让别人控制这台电脑'),
              ]),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error,
                    style: const TextStyle(color: Color(0xFFE53935), fontSize: 13)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BilinColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_register ? '注册并登录' : '登录',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _register = !_register;
                          _error = '';
                        }),
                child: Text(_register ? '已有账号？去登录' : '没有账号？免费注册',
                    style: const TextStyle(color: BilinColors.brand)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
