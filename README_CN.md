# 🚀 CF_Tunnel

一个轻量化、全自动的 Cloudflare Tunnel 管理面板。无需公网 IP，无需配置防火墙端口转发，即可轻松将本地服务（Web、SSH、API 等）发布到公网。

![Web UI 预览](https://img.shields.io/badge/UI-专业简约-blue?style=for-the-badge)
![平台支持](https://img.shields.io/badge/平台-Windows%20|%20Linux%20|%20macOS-success?style=for-the-badge)
![开源协议](https://img.shields.io/badge/协议-MIT-orange?style=for-the-badge)

## ✨ 功能亮点

- **一键安装**：为 Windows 和 Linux 提供全自动安装脚本。
- **智能依赖管理**：自动检测并安装 Node.js、npm 以及适配您系统的最新版 `cloudflared` 二进制文件。
- **现代化面板**：高颜值的专业极简设计，支持深色/浅色模式自适应。
- **动态端口映射**：直接在浏览器中添加、删除或监控端口映射。
- **双语支持**：完整的中英文界面切换支持。
- **零配置**：利用 Cloudflare Quick Tunnels (TryCloudflare) 技术，即开即用。

---

## 🛠️ 安装步骤

### Windows (PowerShell)
打开 PowerShell 并运行：
```powershell
iwr -useb https://cft.imdaxia.com/install.ps1 | iex
```

## 🛠️ 手动安装 (当一键安装脚本失败时)
如果由于网络或环境原因导致一键脚本失败，请按照以下步骤手动部署：

1. **安装 Node.js**：前往 [nodejs.org](https://nodejs.org/) 下载并安装 LTS 版本。
2. **下载本项目**：
   ```bash
   git clone https://github.com/pingpm/CF_Tunnel_webui.git
   cd CF_Tunnel_webui
   ```
   *(或直接下载并解压 [项目 ZIP 包](https://github.com/pingpm/CF_Tunnel_webui/archive/refs/heads/main.zip))*
3. **安装依赖**：
   ```bash
   npm install
   ```
4. **启动服务**：
   ```bash
   node server/index.js
   ```
5. **访问面板**：在浏览器打开 `http://localhost:11122`。

---

## 📖 如何使用

1.  **启动**：运行安装脚本。
2.  **获取访问面板**：查看终端输出的 **Access Link**。
3.  **创建穿透**：在浏览器打开链接，输入本地端口并点击 **Create Tunnel**。

### 一键安装命令 (Curl-to-Install)
```bash
curl -sSL https://cft.imdaxia.com/install.sh | bash
```
