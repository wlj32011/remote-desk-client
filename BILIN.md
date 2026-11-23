# 比邻远程（BiLin）客户端

基于 [RustDesk](https://github.com/rustdesk/rustdesk) 1.5.3（上游提交 95cca3f，hbb_common fae47e0）修改，
遵循 AGPL-3.0（见 LICENCE）。对外分发改过的程序时，必须同时提供本仓库对应版本的完整源码。

## 和上游的区别

- **品牌**：内部名 `BiLin`（配置目录、服务名、`BiLin.exe`），中文界面显示“比邻远程”；图标、logo 换掉；
  关于页、安装页去掉 rustdesk.com 链接，保留 RustDesk 原版权声明。
- **内置配置**：`res/bilin/brand.json` 编译进程序（格式同 RustDesk custom.txt，但不读磁盘、不验签），
  强制服务器 106.15.131.38 与公钥，隐藏服务器设置；强制开 UDP 打洞和 IPv6 直连、关 WebRTC（服务端还没做密钥交换）、
  关官方更新检查。`libs/hbb_common/src/config.rs` 默认值同步改了。
- **直连优先**（`src/client.rs`）：上游只在带 WebRTC 时才“压住中转结果、给直连留回落等待时间”；
  这里两处赛跑都改成直连优先：
  1. 首选请求（带 UDP 端口 / IPv6）和只带 TCP 打洞的备用请求赛跑；
  2. 被控端回中转但附带 IPv6 地址时，IPv6 打洞和中转赛跑。
  原来中转的 TCP 连接总是先到，可用的 IPv6/UDP 直连被丢掉。
- **hbb_common** 从子模块改为直接放在仓库里（要改里面的默认值）。
- **CI**：只留 `.github/workflows/bilin-windows.yml`（手动触发，Windows x64）和它用到的 `bridge.yml`。

## 构建

GitHub → Actions → BiLin Windows build → Run workflow，产物在该次运行的 Artifacts 里。

## 服务端

配套改过的 hbbs（转发 UDP/IPv6 打洞信息）见 rustdesk-server 分支 remote-desk 的补丁。
