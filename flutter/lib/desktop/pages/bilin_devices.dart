// 比邻远程：设备列表（11-24 用户要求）
// - 登录后，同账号的电脑互相远程不用输密码：每台电脑把自己固定密码的哈希写进账号的个人地址簿，
//   别的电脑连它时 RustDesk 自动用地址簿里的哈希登录（client.rs try_get_password_from_personal_ab）
// - 不放“文件传输”入口：远程时直接复制粘贴就能传文件
// - 单击一台出“远程控制”和更多操作；右键或“批量管理”可多选：重启、关机、改备注、移到分组
// - 分组 = 个人地址簿的标签，备注 = 地址簿别名，都存在账号里，所有电脑看到的一样
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/desktop/pages/bilin_home.dart';
import 'package:flutter_hbb/generated_bridge.dart' show EventToUI_Event;
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

// ================= 账号设备同步 =================

bool _syncing = false;

/// 个人地址簿（不存在时为 null）
BaseAb? bilinAb() =>
    gFFI.abModel.addressbooks[gFFI.abModel.personalAddressBookName()];

/// 把本机（带免密哈希）放进个人地址簿，并清理本机的重复记录。启动后、登录后、打开设备列表时调用。
Future<void> bilinSyncAccountDevices() async {
  if (_syncing || !gFFI.userModel.isLogin) return;
  _syncing = true;
  try {
    bilinAbRowCount.clear();
    await gFFI.abModel
        .pullAb(force: ForcePullAb.listAndCurrent, quiet: true);
    final name = gFFI.abModel.personalAddressBookName();
    var ab = bilinAb();
    if (ab == null) return;
    if (gFFI.abModel.currentName.value != name) {
      await gFFI.abModel.setCurrentName(name);
    }
    final myId = await bind.mainGetMyId();
    if (myId.isEmpty) return;
    final hash = await bind.mainGetCommon(key: 'bilin-self-ab-hash');
    String host = '';
    try {
      host = jsonDecode(bind.mainGetLoginDeviceInfo())['name'] ?? '';
    } catch (_) {}
    final platform = Platform.isWindows
        ? 'Windows'
        : (Platform.isMacOS ? 'Mac OS' : 'Linux');

    // 只加本机，不替别的电脑加：两台电脑同时启动互相添加会在服务器上生成重复记录，
    // 重复记录里没有密码哈希，会让免密失效（0.5.0 的问题）。每台电脑登录后自己加自己。
    final mine = ab.peers.firstWhereOrNull((p) => p.id == myId);
    if (mine == null) {
      await gFFI.abModel.addPeersTo(
          [{'id': myId, 'hostname': host, 'platform': platform}], name);
      ab = bilinAb();
    } else if ((bilinAbRowCount[myId] ?? 0) > 1) {
      // 服务器上本机有重复记录：逐条删掉（服务器一次只删一条）后按合并结果重新加一条
      final keep = <String, dynamic>{
        'id': myId,
        'hostname': host.isNotEmpty ? host : mine.hostname,
        'platform': platform,
        'alias': mine.alias,
        'tags': mine.tags,
      };
      final rows = bilinAbRowCount[myId]!;
      var deleted = true;
      for (var i = 0; i < rows && deleted; i++) {
        deleted = await gFFI.abModel.deletePeers([myId]);
      }
      if (deleted) {
        await gFFI.abModel.addPeersTo([keep], name);
        ab = bilinAb();
      }
    }
    final me = ab?.peers.firstWhereOrNull((p) => p.id == myId);
    if (me != null) {
      if (hash.isNotEmpty && me.hash != hash) {
        await gFFI.abModel.changePersonalHashPassword(myId, hash);
      }
      // 本机改了计算机名，跟着更新
      if (host.isNotEmpty && me.hostname != host && me.alias.isEmpty) {
        me.hostname = host;
      }
    }
  } catch (e) {
    debugPrint('bilin sync account devices: $e');
  } finally {
    _syncing = false;
  }
}

/// 从设备列表远程：本地缓存里对方还没有免密哈希（对方刚登录、刚升级）时，先重新拉一次地址簿再连，
/// 这样不用等手动刷新就能免密。
Future<void> bilinConnect(BuildContext context, String id) async {
  final p = bilinAb()?.peers.firstWhereOrNull((e) => e.id == id);
  if (p != null && p.hash.isEmpty) {
    try {
      await gFFI.abModel
          .pullAb(force: ForcePullAb.current, quiet: true)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
  // 远程窗口的标签读本机保存的备注，连接前把账号设备列表里的备注同步过去
  final latest = bilinAb()?.peers.firstWhereOrNull((e) => e.id == id);
  final alias = latest?.alias ?? '';
  if (alias.isNotEmpty &&
      bind.mainGetPeerOptionSync(id: id, key: 'alias') != alias) {
    await bind.mainSetPeerAlias(id: id, alias: alias);
  }
  if (!context.mounted) return;
  connect(context, id);
}

// ================= 无窗口连接：重启 / 关机 =================

/// 后台连上对方（用地址簿里的哈希免密登录），发重启或关机指令后断开。成功返回 null，失败返回原因。
Future<String?> bilinPowerOne(String id, String action) async {
  final sid = const Uuid().v4obj();
  final addErr = bind.sessionAddSync(
    sessionId: sid,
    id: id,
    isFileTransfer: false,
    isViewCamera: false,
    isPortForward: false,
    isRdp: false,
    isTerminal: false,
    switchUuid: '',
    forceRelay: false,
    password: '',
    isSharedPassword: false,
    connToken: null,
    loginMethod: '',
  );
  if (addErr.isNotEmpty) return addErr;
  final done = Completer<String?>();
  StreamSubscription? sub;
  sub = bind.sessionStart(sessionId: sid, id: id).listen((e) async {
    if (e is! EventToUI_Event || done.isCompleted) return;
    Map<String, dynamic> m;
    try {
      m = jsonDecode(e.field0);
    } catch (_) {
      return;
    }
    final name = m['name'];
    if (name == 'peer_info') {
      if (action == 'restart') {
        await bind.sessionRestartRemoteDevice(sessionId: sid);
      } else {
        await bind.sessionToggleOption(sessionId: sid, value: 'bilin-shutdown');
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!done.isCompleted) done.complete(null);
    } else if (name == 'msgbox') {
      final type = '${m['type'] ?? ''}';
      final text = '${m['text'] ?? ''}';
      if (type.contains('password')) {
        done.complete('需要密码（对方还没装新版，或没登录这个账号）');
      } else if (type.contains('error')) {
        done.complete(translate(text));
      }
    }
  });
  String? r;
  try {
    r = await done.future.timeout(const Duration(seconds: 25));
  } on TimeoutException {
    r = '连接超时';
  }
  await sub.cancel();
  await bind.sessionClose(sessionId: sid);
  return r;
}

// ================= 设备列表页 =================

class BilinDevicesPage extends StatefulWidget {
  const BilinDevicesPage({Key? key}) : super(key: key);

  @override
  State<BilinDevicesPage> createState() => _BilinDevicesPageState();
}

class _BilinDevicesPageState extends State<BilinDevicesPage> {
  String _group = 'default'; // default（默认分组＝没进任何分组的）/ tag:<分组名>
  String _filter = 'all'; // all / online / offline
  String _selected = '';
  bool _batch = false;
  final Set<String> _checked = {};
  final _search = TextEditingController();
  Timer? _timer;
  Worker? _abWorker;
  String _myId = '';
  // 自己记一份在线状态：地址簿刷新会换新设备对象、清空 online，靠这份避免闪成“离线”
  final Map<String, bool> _online = {};
  static const _onlineHandler = 'bilin-devices-onlines';

  @override
  void initState() {
    super.initState();
    bind.mainLoadRecentPeers();
    bind.mainGetMyId().then((v) => setState(() => _myId = v));
    bilinSyncAccountDevices().then((_) => _queryOnline());
    platformFFI.registerEventHandler('callback_query_onlines', _onlineHandler,
        (evt) async {
      if (!mounted) return;
      setState(() {
        for (final id in '${evt['onlines'] ?? ''}'.split(',')) {
          if (id.isNotEmpty) _online[id] = true;
        }
        for (final id in '${evt['offlines'] ?? ''}'.split(',')) {
          if (id.isNotEmpty) _online[id] = false;
        }
      });
    }, replace: true);
    // 3 秒查一次在线状态（对方上线几秒内显示，下线约 20 秒内显示）
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _queryOnline());
    // 地址簿一刷新（改备注、分组等），设备对象会换新、在线状态清空，马上重新查
    _abWorker = ever(gFFI.abModel.currentAbPeers,
        (_) => Future.delayed(const Duration(milliseconds: 300), _queryOnline));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _abWorker?.dispose();
    platformFFI.unregisterEventHandler('callback_query_onlines', _onlineHandler);
    _search.dispose();
    super.dispose();
  }

  List<Peer> get _accountPeers => bilinAb()?.peers.toList() ?? [];
  List<String> get _tags => bilinAb()?.tags.toList() ?? [];

  void _queryOnline() {
    final ids = <String>{
      ..._accountPeers.map((p) => p.id),
      ...gFFI.recentPeersModel.peers.map((p) => p.id),
    }..remove(_myId);
    if (ids.isNotEmpty) bind.queryOnlines(ids: ids.toList());
  }

  bool _isOn(Peer p) => p.id == _myId || (_online[p.id] ?? p.online);

  List<Peer> _peersOf(String group) {
    final all = _accountPeers;
    if (group == 'search') return all; // 搜索时在所有设备里找
    if (group == 'default') {
      final tags = _tags;
      return all.where((p) => !p.tags.any((t) => tags.contains(t))).toList();
    }
    if (group.startsWith('tag:')) {
      final t = group.substring(4);
      return all.where((p) => p.tags.contains(t)).toList();
    }
    return all;
  }

  String _name(Peer p) {
    if (p.alias.isNotEmpty) return p.alias;
    if (p.hostname.isNotEmpty) return p.hostname;
    return groupId(p.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        gFFI.abModel.peersModel,
        gFFI.recentPeersModel,
        gFFI.groupModel.peersModel,
      ]),
      builder: (context, _) => Obx(() {
        // 让 Obx 跟踪地址簿变化
        gFFI.abModel.addressbooks.length;
        bilinAb()?.peers.length;
        bilinAb()?.tags.length;
        gFFI.userModel.userName.value;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _left(context),
            VerticalDivider(width: 1, color: BilinColors.border(context)),
            Expanded(child: _right(context)),
          ],
        );
      }),
    );
  }

  // ---------- 左侧：搜索 + 分组 ----------

  Widget _left(BuildContext context) {
    final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
    Widget item(String key, IconData icon, String name, List<Peer> peers,
        {String? tag}) {
      final selected = _group == key;
      final online = peers.where(_isOn).length;
      return Material(
        color:
            selected ? BilinColors.brand.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _group = key;
            _selected = '';
            _checked.clear();
          }),
          onSecondaryTapDown:
              tag == null ? null : (d) => _tagMenu(context, tag, d.globalPosition),
          child: SizedBox(
            height: 40,
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(icon,
                  size: 19,
                  color:
                      selected ? BilinColors.brand : BilinColors.sub(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? BilinColors.brand
                            : BilinColors.text(context))),
              ),
              Text('$online/${peers.length}',
                  style:
                      TextStyle(fontSize: 12, color: BilinColors.sub(context))),
              if (tag != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTapDown: (d) => _tagMenu(context, tag, d.globalPosition),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz,
                        size: 16, color: BilinColors.sub(context)),
                  ),
                )
              else
                const SizedBox(width: 12),
            ]),
          ),
        ),
      );
    }

    Widget header(String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
          child: Row(children: [
            Text(text,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BilinColors.sub(context))),
            const Spacer(),
            if (trailing != null) trailing,
          ]),
        );

    final tags = _tags;
    return Container(
      width: 250,
      color: BilinColors.card(context),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
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
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '新建分组',
              child: Material(
                color: BilinColors.field(context),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: loggedIn
                      ? () => _newGroupDialog(context)
                      : () => showBilinLoginDialog(context),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(Icons.add,
                        size: 22, color: BilinColors.text(context)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          header('我的设备'),
          Expanded(
            child: ListView(
              children: [
                item('default', Icons.folder_outlined, '默认分组',
                    _peersOf('default')),
                for (final t in tags)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: item('tag:$t', Icons.folder_outlined, t,
                        _peersOf('tag:$t'),
                        tag: t),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 右侧：列表 ----------

  Widget _right(BuildContext context) {
    final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
    if (!loggedIn) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.devices_outlined, size: 56, color: BilinColors.sub(context)),
          const SizedBox(height: 14),
          Text('登录账号后，同一账号的电脑都会出现在这里，互相远程不用输密码',
              style: TextStyle(fontSize: 14, color: BilinColors.sub(context))),
          const SizedBox(height: 18),
          SizedBox(
            width: 160,
            height: 44,
            child: ElevatedButton(
              onPressed: () => showBilinLoginDialog(context),
              style: _primary(),
              child: const Text('登录 / 注册', style: TextStyle(fontSize: 15)),
            ),
          ),
        ]),
      );
    }
    final kw = _search.text.trim().toLowerCase();
    final all = _peersOf(kw.isNotEmpty ? 'search' : _group);
    final searched = all.where((p) {
      if (kw.isEmpty) return true;
      return p.id.contains(kw.replaceAll(' ', '')) ||
          p.alias.toLowerCase().contains(kw) ||
          p.hostname.toLowerCase().contains(kw);
    }).toList();
    final online = searched.where(_isOn).length;
    final shown = searched.where((p) {
      if (_filter == 'online') return _isOn(p);
      if (_filter == 'offline') return !_isOn(p);
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.id == _myId) return -1;
        if (b.id == _myId) return 1;
        if (_isOn(a) != _isOn(b)) return _isOn(a) ? -1 : 1;
        return _name(a).compareTo(_name(b));
      });
    _checked.removeWhere((id) => !shown.any((p) => p.id == id));

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
                    color: sel
                        ? BilinColors.card(context)
                        : BilinColors.sub(context))),
          ),
        ),
      );
    }

    final title = kw.isNotEmpty
        ? '搜索结果'
        : (_group == 'default' ? '默认分组' : _group.substring(4));
    const canManage = true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: BilinColors.text(context))),
            ),
            if (canManage)
              TextButton.icon(
                onPressed: () => setState(() {
                  _batch = !_batch;
                  _checked.clear();
                }),
                icon: Icon(_batch ? Icons.close : Icons.checklist_rounded,
                    size: 18),
                label: Text(_batch ? '退出批量' : '批量管理'),
                style: TextButton.styleFrom(
                    foregroundColor:
                        _batch ? BilinColors.sub(context) : BilinColors.brand),
              ),
            IconButton(
              tooltip: '刷新',
              onPressed: () async {
                await bilinSyncAccountDevices();
                _queryOnline();
              },
              icon: Icon(Icons.refresh_rounded, color: BilinColors.sub(context)),
            ),
          ]),
          const SizedBox(height: 8),
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
                        kw.isNotEmpty
                            ? '没找到匹配的设备'
                            : (_accountPeers.isEmpty
                                ? '没有设备。在别的电脑上安装比邻远程并登录同一账号，就会出现在这里'
                                : (_group == 'default'
                                    ? '默认分组里没有电脑'
                                    : '这个分组还没有电脑。在设备上右键，选“移到分组”')),
                        style: TextStyle(
                            fontSize: 14, color: BilinColors.sub(context))))
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) =>
                        _row(context, shown[i], canManage),
                  ),
          ),
          if (_batch && canManage) _batchBar(context, shown),
        ],
      ),
    );
  }

  ButtonStyle _primary() => ElevatedButton.styleFrom(
        backgroundColor: BilinColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _tag(String text, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
      );

  Widget _row(BuildContext context, Peer p, bool canManage) {
    final isMe = p.id == _myId;
    final on = _isOn(p);
    final sel = !_batch && _selected == p.id;
    final checked = _checked.contains(p.id);
    void toggle() => setState(() {
          if (checked) {
            _checked.remove(p.id);
          } else {
            _checked.add(p.id);
          }
        });
    return Material(
      color: (sel || (_batch && checked))
          ? BilinColors.brand
              .withOpacity(BilinColors.isDark(context) ? 0.2 : 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _batch ? toggle : () => setState(() => _selected = p.id),
        onDoubleTap: (_batch || isMe) ? null : () => bilinConnect(context, p.id),
        onSecondaryTapDown: canManage && !_batch
            ? (d) {
                setState(() => _selected = p.id);
                _peerMenu(context, p, d.globalPosition);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            if (_batch) ...[
              Checkbox(
                value: checked,
                onChanged: (_) => toggle(),
                activeColor: BilinColors.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
            ],
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                  BilinColors.text(context).withOpacity(on ? 0.75 : 0.35),
                  BlendMode.srcIn),
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
                      _tag('本机', BilinColors.text(context),
                          BilinColors.field(context))
                    else if (on)
                      _tag('在线', const Color(0xFF16A34A),
                          const Color(0xFFDCFCE7))
                    else
                      _tag('离线', BilinColors.sub(context),
                          BilinColors.field(context)),
                    Text(groupId(p.id),
                        style: TextStyle(
                            fontSize: 13, color: BilinColors.sub(context))),
                    if (p.tags.isNotEmpty && !_group.startsWith('tag:')) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.folder_outlined,
                          size: 13, color: BilinColors.sub(context)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(p.tags.join('、'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: BilinColors.sub(context))),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            if (sel) ...[
              if (!isMe)
                ElevatedButton(
                  onPressed: () => bilinConnect(context, p.id),
                  style: _primary(),
                  child: const Text('远程控制'),
                ),
              if (canManage)
                Builder(
                  builder: (bctx) => IconButton(
                    tooltip: '更多',
                    onPressed: () {
                      final box = bctx.findRenderObject() as RenderBox;
                      _peerMenu(context, p,
                          box.localToGlobal(Offset(0, box.size.height)));
                    },
                    icon: Icon(Icons.more_vert, color: BilinColors.sub(context)),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _batchBar(BuildContext context, List<Peer> shown) {
    final all = shown.isNotEmpty && _checked.length == shown.length;
    final picked = shown.where((p) => _checked.contains(p.id)).toList();
    Widget btn(String text, IconData icon, VoidCallback? onTap,
            {Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: OutlinedButton.icon(
            onPressed: picked.isEmpty ? null : onTap,
            icon: Icon(icon, size: 17),
            label: Text(text),
            style: OutlinedButton.styleFrom(
              foregroundColor: color ?? BilinColors.text(context),
              side: BorderSide(color: BilinColors.border(context)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: BilinColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BilinColors.border(context)),
      ),
      child: Row(children: [
        Checkbox(
          value: all,
          onChanged: (_) => setState(() {
            if (all) {
              _checked.clear();
            } else {
              _checked.addAll(shown.map((p) => p.id));
            }
          }),
          activeColor: BilinColors.brand,
        ),
        Text('已选 ${picked.length} 台',
            style: TextStyle(fontSize: 14, color: BilinColors.text(context))),
        const Spacer(),
        btn('移到分组', Icons.drive_file_move_outline,
            () => _moveDialog(context, picked)),
        btn('重启', Icons.restart_alt, () => _power(context, picked, 'restart')),
        btn('关机', Icons.power_settings_new,
            () => _power(context, picked, 'shutdown'),
            color: const Color(0xFFDC2626)),
      ]),
    );
  }

  // ---------- 菜单和对话框 ----------

  Future<void> _peerMenu(BuildContext context, Peer p, Offset pos) async {
    final isMe = p.id == _myId;
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: [
        if (!isMe)
          const PopupMenuItem(value: 'connect', child: Text('远程控制')),
        const PopupMenuItem(value: 'alias', child: Text('修改备注')),
        const PopupMenuItem(value: 'move', child: Text('移到分组')),
        if (!isMe) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'restart', child: Text('重启')),
          const PopupMenuItem(
              value: 'shutdown',
              child: Text('关机', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ],
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'connect':
        bilinConnect(context, p.id);
        break;
      case 'alias':
        _aliasDialog(context, p);
        break;
      case 'move':
        _moveDialog(context, [p]);
        break;
      case 'restart':
      case 'shutdown':
        _power(context, [p], v);
        break;
    }
  }

  Future<void> _tagMenu(BuildContext context, String tag, Offset pos) async {
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('重命名分组')),
        PopupMenuItem(
            value: 'delete',
            child: Text('删除分组', style: TextStyle(color: Color(0xFFDC2626)))),
      ],
    );
    if (!mounted || v == null) return;
    if (v == 'rename') {
      final name = await _inputDialog(context, '重命名分组', '分组名称', tag);
      if (name == null || name.isEmpty || name == tag) return;
      if (_tags.contains(name)) {
        showToast('已经有叫“$name”的分组了');
        return;
      }
      await gFFI.abModel.renameTag(tag, name);
      if (_group == 'tag:$tag') setState(() => _group = 'tag:$name');
    } else {
      final ok = await _confirm(context, '删除分组',
          '删除分组“$tag”？分组里的电脑不会删除，只是不再属于这个分组。', '删除');
      if (!ok) return;
      await gFFI.abModel.deleteTag(tag);
      if (_group == 'tag:$tag') setState(() => _group = 'default');
    }
  }

  Future<void> _newGroupDialog(BuildContext context) async {
    final name = await _inputDialog(context, '新建分组', '分组名称，比如：办公室、家里', '');
    if (name == null || name.isEmpty) return;
    if (_tags.contains(name)) {
      showToast('已经有这个分组了');
      return;
    }
    await gFFI.abModel.addTags([name]);
    setState(() => _group = 'tag:$name');
  }

  Future<void> _aliasDialog(BuildContext context, Peer p) async {
    final v = await _inputDialog(context, '修改备注',
        '给这台电脑起个好认的名字（留空就显示计算机名）', p.alias);
    if (v == null) return;
    await gFFI.abModel.changeAlias(id: p.id, alias: v);
    setState(() {});
  }

  Future<void> _moveDialog(BuildContext context, List<Peer> peers) async {
    if (peers.isEmpty) return;
    final tags = _tags;
    String? chosen = peers.length == 1 && peers.first.tags.isNotEmpty
        ? '${peers.first.tags.first}'
        : null;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(peers.length == 1
              ? '把“${_name(peers.first)}”移到分组'
              : '把 ${peers.length} 台电脑移到分组'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final t in [...tags, ''])
                RadioListTile<String>(
                  value: t,
                  groupValue: chosen ?? '',
                  onChanged: (v) => setS(() => chosen = v),
                  title: Text(t.isEmpty ? '默认分组' : t),
                  dense: true,
                  activeColor: BilinColors.brand,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final name =
                        await _inputDialog(ctx, '新建分组', '分组名称', '');
                    if (name == null || name.isEmpty) return;
                    if (!tags.contains(name)) {
                      await gFFI.abModel.addTags([name]);
                      tags.add(name);
                    }
                    setS(() => chosen = name);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建分组'),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, chosen ?? ''),
                style: _primary(),
                child: const Text('确定')),
          ],
        ),
      ),
    );
    if (r == null) return;
    await gFFI.abModel
        .changeTagForPeers(peers.map((p) => p.id).toList(), r.isEmpty ? [] : [r]);
    setState(() {
      _batch = false;
      _checked.clear();
    });
    showToast(r.isEmpty ? '已移到“默认分组”' : '已移到“$r”');
  }

  Future<void> _power(BuildContext context, List<Peer> peers, String action) async {
    final word = action == 'restart' ? '重启' : '关机';
    final targets = peers.where((p) => p.id != _myId).toList();
    if (targets.isEmpty) {
      showToast('不能对本机$word');
      return;
    }
    final names = targets.map(_name).take(8).join('、') +
        (targets.length > 8 ? ' 等' : '');
    final ok = await _confirm(
      context,
      '$word ${targets.length} 台电脑',
      '确定让 $names 立即$word？\n'
          '${action == 'restart' ? '电脑会马上重启，没保存的文件会丢失。' : '电脑会马上关机，没保存的文件会丢失；关机后要到电脑跟前按电源键才能开机。'}',
      word,
      danger: action == 'shutdown',
    );
    if (!ok || !mounted) return;
    final results = <String, String?>{};
    final progress = 0.obs;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Obx(() => Row(children: [
              const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 16),
              Text('正在$word… ${progress.value}/${targets.length}'),
            ])),
      ),
    );
    // 有设备缺免密哈希时先拉一次最新地址簿
    if (targets.any((p) => p.hash.isEmpty)) {
      try {
        await gFFI.abModel
            .pullAb(force: ForcePullAb.current, quiet: true)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    // 最多同时 4 台
    final queue = [...targets];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final p = queue.removeAt(0);
        results[p.id] = _isOn(p) ? await bilinPowerOne(p.id, action) : '离线';
        progress.value++;
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final failed = targets.where((p) => results[p.id] != null).toList();
    setState(() {
      _batch = false;
      _checked.clear();
    });
    if (failed.isEmpty) {
      showToast('已向 ${targets.length} 台电脑发出$word指令');
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$word：成功 ${targets.length - failed.length} 台，失败 ${failed.length} 台'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in failed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${_name(p)}：${results[p.id]}'),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: _primary(),
              child: const Text('知道了')),
        ],
      ),
    );
  }

  Future<bool> _confirm(
      BuildContext context, String title, String text, String okText,
      {bool danger = true}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 400, child: Text(text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  danger ? const Color(0xFFDC2626) : BilinColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(okText),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<String?> _inputDialog(
      BuildContext context, String title, String hint, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 30,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: _primary(),
              child: const Text('确定')),
        ],
      ),
    );
    ctrl.dispose();
    return r;
  }
}
