// 比邻远程：桌面版主页（参考向日葵 / 连连控 / UU 远程的布局重做）
// 左侧窄导航：远程协助、设备列表、设置；
// 「远程协助」页：左卡片“允许控制本机”（识别码 + 临时密码），右卡片“控制远程设备”（输入识别码 + 两个大按钮）；
// 底部常驻防骗提醒和服务状态。只用公开 API（gFFI / bind / connect），不改 RustDesk 的连接逻辑。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart'
    show OnlineStatusWidget;
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class BilinColors {
  static const brand = Color(0xFF2B6CFF);
  static const brand2 = Color(0xFF17C3B2);
  static const gradient = LinearGradient(
    colors: [brand, Color(0xFF1E9BE0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color page(BuildContext c) =>
      isDark(c) ? const Color(0xFF1B1D22) : const Color(0xFFF3F5F9);
  static Color sidebar(BuildContext c) =>
      isDark(c) ? const Color(0xFF15171B) : Colors.white;
  static Color card(BuildContext c) =>
      isDark(c) ? const Color(0xFF24272E) : Colors.white;
  static Color field(BuildContext c) =>
      isDark(c) ? const Color(0xFF2E323A) : const Color(0xFFF4F6FA);
  static Color border(BuildContext c) =>
      isDark(c) ? const Color(0xFF33373F) : const Color(0xFFE6E9F0);
  static Color text(BuildContext c) =>
      isDark(c) ? const Color(0xFFF2F3F5) : const Color(0xFF1F2937);
  static Color sub(BuildContext c) =>
      isDark(c) ? const Color(0xFF9AA0AA) : const Color(0xFF6B7280);
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
                Expanded(child: _AssistPage(notice: widget.notice)),
                const _FraudTipBar(),
                Container(
                  color: BilinColors.card(context),
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
      width: 84,
      decoration: BoxDecoration(
        color: BilinColors.sidebar(context),
        border: Border(right: BorderSide(color: BilinColors.border(context))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/icon.png', width: 40, height: 40),
          ),
          const SizedBox(height: 22),
          _navItem(context, 0, Icons.screen_share_outlined, '远程协助'),
          const Spacer(),
          _sideButton(context, Icons.settings_outlined, '设置', () {
            if (DesktopSettingPage.tabKeys.isNotEmpty) {
              DesktopSettingPage.switch2page(DesktopSettingPage.tabKeys[0]);
            } else {
              DesktopTabPage.onAddSetting();
            }
          }),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    return Obx(() {
      final selected = _nav.value == index;
      return _sideButton(context, icon, label, () => _nav.value = index,
          selected: selected);
    });
  }

  Widget _sideButton(
      BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool selected = false}) {
    final color = selected ? BilinColors.brand : BilinColors.sub(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: selected
            ? BilinColors.brand.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片外壳
class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _Card(
      {required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BilinColors.border(context)),
        boxShadow: BilinColors.isDark(context)
            ? null
            : [
                BoxShadow(
                    color: const Color(0xFF1F2937).withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: BilinColors.text(context))),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(fontSize: 12.5, color: BilinColors.sub(context))),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// 「远程协助」页：上面两张卡片，下面是最近连接 / 收藏 / 地址簿
class _AssistPage extends StatelessWidget {
  final Widget? notice;
  const _AssistPage({this.notice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
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
          const SizedBox(height: 16),
          const Expanded(child: _DevicesPanel()),
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
          title: '允许控制本机',
          subtitle: '把下面的识别码和密码告诉你信任的人，对方就能远程协助你',
          children: [
            _InfoField(
              label: '本机识别码',
              listenable: model.serverId,
              value: () => _groupId(model.serverId.text),
              copyText: () => model.serverId.text,
              big: true,
            ),
            const SizedBox(height: 14),
            _PasswordField(model: model, showOneTime: showOneTime),
          ],
        );
      }),
    );
  }

  static String _groupId(String id) {
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
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: BilinColors.sub(context)),
        ),
      ),
    );
  }
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: BilinColors.field(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12.5, color: BilinColors.sub(context))),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: listenable,
                  builder: (context, _) => SelectableText(
                    value(),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: big ? 30 : 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: BilinColors.field(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.showOneTime ? '临时密码' : '访问密码',
              style: TextStyle(fontSize: 12.5, color: BilinColors.sub(context))),
          const SizedBox(height: 4),
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
                        fontSize: widget.showOneTime ? 22 : 15,
                        fontWeight: widget.showOneTime
                            ? FontWeight.w700
                            : FontWeight.normal,
                        letterSpacing: widget.showOneTime ? 1.5 : 0,
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
                _IconBtn(Icons.refresh_rounded, '换一个密码',
                    () => bind.mainUpdateTemporaryPassword()),
                _IconBtn(Icons.copy_rounded, '复制', () {
                  Clipboard.setData(
                      ClipboardData(text: model.serverPasswd.text));
                  showToast(translate('Copied'));
                }),
              ],
              if (!bind.isDisableSettings())
                _IconBtn(Icons.edit_outlined, '设置固定密码',
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
    return _Card(
      title: '控制远程设备',
      subtitle: '输入对方的识别码，连接后按提示输入对方的密码',
      children: [
        TextField(
          controller: _idCtrl,
          focusNode: _focus,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [IDTextInputFormatter()],
          onSubmitted: (_) => _go(),
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: BilinColors.text(context)),
          decoration: InputDecoration(
            hintText: '输入对方识别码',
            hintStyle: TextStyle(
                fontSize: 17,
                letterSpacing: 0,
                fontWeight: FontWeight.normal,
                color: BilinColors.sub(context)),
            filled: true,
            fillColor: BilinColors.field(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: BilinColors.brand, width: 1.5)),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _go(file: true),
                  icon: const Icon(Icons.folder_copy_outlined, size: 19),
                  label: const Text('文件传输', style: TextStyle(fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BilinColors.brand,
                    side: BorderSide(
                        color: BilinColors.brand.withOpacity(0.55), width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: BilinColors.gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _go(),
                    icon: const Icon(Icons.desktop_windows_outlined, size: 19),
                    label: const Text('远程控制',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('连接前请确认对方是你认识的人。',
            style: TextStyle(fontSize: 12, color: BilinColors.sub(context))),
      ],
    );
  }
}

/// 最近连接 / 收藏 / 地址簿（沿用 RustDesk 的列表组件）
class _DevicesPanel extends StatelessWidget {
  const _DevicesPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 4),
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BilinColors.border(context)),
      ),
      child: const PeerTabPage(),
    );
  }
}

/// 底部常驻防骗提醒
class _FraudTipBar extends StatelessWidget {
  const _FraudTipBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      color: BilinColors.isDark(context)
          ? const Color(0xFF3A2E12)
          : const Color(0xFFFFF7E6),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFE8890C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '防骗提醒：凡是自称客服、警察、银行、领导，让你下载远程软件、报识别码和密码的，都是诈骗。',
              style: TextStyle(
                  fontSize: 12.5,
                  color: BilinColors.isDark(context)
                      ? const Color(0xFFF5C26B)
                      : const Color(0xFF9A5B00)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
