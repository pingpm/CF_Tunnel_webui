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
    # Use a temporary directory or current dir to clone
    REPO_URL="https://github.com/pingpm/CF_Tunnel_webui.git" # IMPORTANT: User should update this to their own URL
    echo -e "${CYAN}📥 Cloning repository from $REPO_URL...${NC}"
    git clone $REPO_URL CF_Tunnel-temp
    cd CF_Tunnel-temp
fi

# 1. Check for Node.js
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}❌ Node.js is not installed.${NC}"
    
    # Try to detect OS and offer install command
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            echo -e "${CYAN}Detected Debian/Ubuntu. Trying to install Node.js...${NC}"
            sudo apt-get update && sudo apt-get install -y nodejs npm
        elif command -v yum &> /dev/null; then
            echo -e "${CYAN}Detected CentOS/RHEL. Trying to install Node.js...${NC}"
            sudo yum install -y nodejs npm
        else
            echo -e "${RED}Please install Node.js manually. Linux: sudo apt install nodejs npm${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${RED}Please install Node.js manually. macOS: brew install node${NC}"
        exit 1
    else
        echo -e "${RED}Unsupported OS for auto-install. Please install Node.js first.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Node.js detected: $(node -v)${NC}"

# 2. Navigate to project directory
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 3. Install dependencies
echo -e "${YELLOW}📦 Installing npm dependencies (this may take a minute)...${NC}"
npm install

# 4. Start the application
echo -e "${CYAN}🌟 Starting the control panel...${NC}"
echo "-------------------------------------------------"
echo -e "${YELLOW}Please wait for the Cloudflare Tunnel to initialize...${NC}"
echo "-------------------------------------------------"

# Run the server
# We use node server/index.js directly. If you want it to run in background, use pm2 or nohup.
node server/index.js

