// 比邻远程：设置页（左分类 + 右详情，带返回键，在主窗口内打开）。设备列表在 bilin_devices.dart
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

export 'package:flutter_hbb/desktop/pages/bilin_devices.dart';

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
