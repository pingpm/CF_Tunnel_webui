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
        echo -e "${GREEN}✅ Existing installation found. Skipping download...${NC}"
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
    fi
    cd "$INSTALL_DIR"
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
echo -e "\n${YELLOW}📦 Installing npm dependencies (this may take a minute)...${NC}"
npm install
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

