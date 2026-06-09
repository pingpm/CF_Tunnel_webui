#!/bin/bash

# Cloudflare Tunnel Control Panel Installer
# Supports Linux and macOS

set -e

# Colors for better visibility
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 Starting CF_Tunnel Installation...${NC}"

# 0. Remote execution handler
# If package.json is missing, it means we are likely running via curl | bash
if [ ! -f "package.json" ] && [ ! -d "server" ]; then
    echo -e "${YELLOW}📂 Detect remote execution. Preparing environment...${NC}"
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git is not installed. Please install git first.${NC}"
        exit 1
    fi
    REPO_URL="https://github.com/pingpm/CF_Tunnel_webui.git"
    INSTALL_DIR="CF_Tunnel-temp"

    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/package.json" ]; then
        echo -e "${GREEN}✅ Existing installation found. Updating to latest version...${NC}"
        cd "$INSTALL_DIR"
        git pull || echo -e "${YELLOW}⚠️  Failed to pull latest changes. Using existing version.${NC}"
    else
        # Remove empty or broken directory if it exists
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "${YELLOW}⚠️  Directory exists but is incomplete. Removing and re-cloning...${NC}"
            rm -rf "$INSTALL_DIR"
        fi
        echo -e "${CYAN}📥 Cloning repository from $REPO_URL...${NC}"
        git clone "$REPO_URL" "$INSTALL_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to clone repository.${NC}"
            read -p "Press Enter to exit..."
            exit 1
        fi
        cd "$INSTALL_DIR"
    fi
fi

# 1. Check for Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed.${NC}"
    echo -e "Please install Node.js (v14+) to continue. Linux: sudo apt install nodejs npm"
    read -p "Press Enter to exit..."
    exit 1
fi

echo -e "${GREEN}✅ Node.js detected: $(node -v)${NC}"

# 2. Install dependencies
echo -e "\n${YELLOW}📦 Preparing installation environment...${NC}"

# Check for China IP to enable acceleration
# Try multiple providers with validation (only accept 2-letter country codes)
detect_country() {
    local result

    # Provider 1: ip-api.com (JSON, no Cloudflare)
    result=$(curl -s --connect-timeout 5 "http://ip-api.com/json/?fields=countryCode" 2>/dev/null | grep -o '"countryCode":"[A-Z]*"' | grep -o '[A-Z]*"$' | tr -d '"')
    if echo "$result" | grep -qE '^[A-Z]{2}$'; then echo "$result"; return; fi

    # Provider 2: ifconfig.co
    result=$(curl -s --connect-timeout 5 "https://ifconfig.co/country-iso" 2>/dev/null | tr -d '[:space:]')
    if echo "$result" | grep -qE '^[A-Z]{2}$'; then echo "$result"; return; fi

    # Provider 3: ipinfo.io
    result=$(curl -s --connect-timeout 5 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]')
    if echo "$result" | grep -qE '^[A-Z]{2}$'; then echo "$result"; return; fi

    echo ""
}

echo -e "${CYAN}🔍 Checking network environment...${NC}"
COUNTRY=$(detect_country)

if [ -z "$COUNTRY" ]; then
    echo -e "${YELLOW}⚠️  Could not detect network region. Proceeding without acceleration.${NC}"
elif [ "$COUNTRY" = "CN" ]; then
    echo -e ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  🌏 Network Environment: Mainland China (CN)     ║${NC}"
    echo -e "${YELLOW}║  GitHub proxy acceleration has been enabled.     ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    echo -e ""
else
    echo -e ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  🌐 Network Environment: International ($COUNTRY)$(printf '%*s' $((14 - ${#COUNTRY})) '')║${NC}"
    echo -e "${GREEN}║  Direct connection will be used.                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo -e ""
fi

if [ "$COUNTRY" = "CN" ]; then
    echo -e "${YELLOW}🔧 Configuring GitHub proxy acceleration...${NC}"
    
    # 1. Detect OS and Architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # 2. Map Architecture
    if [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi

    # 3. Fetch latest cloudflared version from GitHub API
    echo -e "${CYAN}📡 Fetching latest cloudflared version...${NC}"
    LATEST_VERSION=$(curl -sI https://github.com/cloudflare/cloudflared/releases/latest | grep -i location | sed 's/.*\/tag\///' | tr -d '\r' | sed 's/^v//')
    
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION="2026.3.0" # Fallback version
        echo -e "${YELLOW}⚠️  Failed to fetch latest version, using fallback: $LATEST_VERSION${NC}"
    else
        echo -e "${GREEN}✨ Latest version detected: $LATEST_VERSION${NC}"
    fi

    # 4. Construct Binary Filename based on OS
    if [ "$OS" = "darwin" ]; then
        BINARY_FILE="cloudflared-darwin-${ARCH}.tgz"
    elif [ "$OS" = "linux" ]; then
        # Linux usually uses raw binary without extension or with specific name
        BINARY_FILE="cloudflared-linux-${ARCH}"
    else
        echo -e "${YELLOW}⚠️  Unsupported OS for auto-acceleration: $OS. Skipping proxy...${NC}"
    fi

    if [ ! -z "$BINARY_FILE" ]; then
        # 5. Set the acceleration URL
        GITHUB_URL="https://github.com/cloudflare/cloudflared/releases/download/${LATEST_VERSION}/${BINARY_FILE}"
        export CLOUDFLARED_BIN_URL="https://gh-proxy.com/${GITHUB_URL}"
        
        echo -e "${GREEN}🚀 Proxy URL set to: $CLOUDFLARED_BIN_URL${NC}"
    fi
fi

echo -e "\n${YELLOW}📦 Installing npm dependencies (this may take a minute)...${NC}"
if [ "$COUNTRY" = "CN" ]; then
    echo -e "${CYAN}🪞 Using Taobao npm mirror for faster downloads...${NC}"
    npm install --registry=https://registry.npmmirror.com --ignore-scripts
else
    npm install --ignore-scripts
fi
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ npm install failed.${NC}"
    read -p "Press Enter to exit..."
    exit 1
fi

# 3. Start the application
echo -e "\n${GREEN}🌟 Starting the control panel...${NC}"
echo "-------------------------------------------------"
echo -e "${CYAN}Please wait for the Cloudflare Tunnel to initialize...${NC}"
echo "-------------------------------------------------"

node server/index.js

# If node exits, keep the window open so user can see why
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Process exited with an error.${NC}"
fi
read -p "Installation finished. Press Enter to close this terminal..."

