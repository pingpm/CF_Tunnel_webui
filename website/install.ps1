# Try to fix encoding for emojis
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Host.UI.RawUI.WindowTitle = "CF_Tunnel Installer"

Write-Host "`n🚀 Starting CF_Tunnel Installation...`n" -ForegroundColor Cyan

# 0. Remote execution handler
if (!(Test-Path "package.json") -and !(Test-Path "server\index.js")) {
    Write-Host "📥 Project files not found. Preparing to fetch code..." -ForegroundColor Yellow
    
    $REPO_URL = "https://github.com/pingpm/CF_Tunnel_webui"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "📥 Cloning repository via Git..." -ForegroundColor Cyan
        git clone "$REPO_URL.git" "CF_Tunnel-temp"
        if (Test-Path "CF_Tunnel-temp") { Set-Location -Path "CF_Tunnel-temp" }
    } else {
        Write-Host "⚠️  Git not detected. Downloading ZIP archive instead..." -ForegroundColor Yellow
        $zipFile = "$env:TEMP\cft_latest.zip"
        
        try {
            Invoke-WebRequest -Uri "$REPO_URL/archive/refs/heads/main.zip" -OutFile $zipFile
            Write-Host "📦 Extracting files..." -ForegroundColor Cyan
            Expand-Archive -Path $zipFile -DestinationPath "$PWD" -Force
            Remove-Item $zipFile
            
            # Dynamically find the extracted folder (GitHub ZIPs are usually RepoName-BranchName)
            $extractedFolder = Get-ChildItem -Directory | Where-Object { $_.Name -like "*CF_Tunnel_webui-main*" } | Select-Object -First 1
            if ($extractedFolder) {
                Set-Location -Path $extractedFolder.FullName
            } else {
                Write-Host "❌ Could not find the extracted folder." -ForegroundColor Red
                exit
            }
        } catch {
            Write-Host "❌ Failed to download or extract the project." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            exit
        }
    }
}

# 1. Check for Node.js
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js is not installed." -ForegroundColor Red
    Write-Host "💡 Attempting to install Node.js via winget..." -ForegroundColor Yellow
    
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "📥 Downloading and installing Node.js LTS..." -ForegroundColor Cyan
        winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
        
        Write-Host "✅ Node.js installation started." -ForegroundColor Green
        Write-Host "🔄 Restarting PowerShell to apply environment changes..." -ForegroundColor Yellow
        
        # Launch a new PowerShell that continues the same command and then exit this one
        $currentCommand = "iwr -useb https://cft.imdaxia.com/install.ps1 | iex"
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "& { $currentCommand }"
        exit
    } else {
        Write-Host "Please install Node.js manually from https://nodejs.org/" -ForegroundColor Yellow
        Read-Host "Press Enter to exit..."
        exit
    }
}

Write-Host "✅ Node.js detected: $(node -v)" -ForegroundColor Green

# 2. Install dependencies
Write-Host "`n📦 Installing npm dependencies (this may take a minute)..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ npm install failed." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

# 3. Start the application
Write-Host "`n🌟 Starting the control panel..." -ForegroundColor Green
Write-Host "-------------------------------------------------"
Write-Host "Please wait for the Cloudflare Tunnel to initialize..." -ForegroundColor Cyan
Write-Host "-------------------------------------------------`n"

node server/index.js

# If node exits, keep the window open so user can see why
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Process exited with error code $LASTEXITCODE" -ForegroundColor Red
}
Read-Host "`nInstallation finished. Press Enter to close this window..."

