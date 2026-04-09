# Set encoding and security protocol for modern web connections
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Host.UI.RawUI.WindowTitle = "CF_Tunnel Installer"

Write-Host "`n🚀 Starting CF_Tunnel Installation...`n" -ForegroundColor Cyan

# 0. Remote execution handler
if (!(Test-Path "package.json") -and !(Test-Path "server\index.js")) {
    Write-Host "📥 Project files not found. Preparing to fetch code..." -ForegroundColor Yellow
    
    $REPO_URL = "https://github.com/pingpm/CF_Tunnel_webui"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $installDir = "CF_Tunnel-temp"
        if ((Test-Path "$installDir\package.json")) {
            Write-Host "✅ Existing installation found. Skipping download..." -ForegroundColor Green
        } else {
            if (Test-Path $installDir) {
                Write-Host "⚠️  Directory exists but is incomplete. Removing and re-cloning..." -ForegroundColor Yellow
                Remove-Item -Recurse -Force $installDir
            }
            Write-Host "📥 Cloning repository via Git..." -ForegroundColor Cyan
            git clone "$REPO_URL.git" $installDir
        }
        if (Test-Path $installDir) { Set-Location -Path $installDir }
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
            Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Gray
            Read-Host "Press Enter to exit..."
            exit
        }
    }
}

# 1. Check for Node.js and handle installation
$portableNodeDir = "$PWD\node-bin"
$nodeExe = "node"

function Check-Node {
    if (Get-Command node -ErrorAction SilentlyContinue) { return $true }
    if (Test-Path "$portableNodeDir\node.exe") { 
        $script:nodeExe = "$portableNodeDir\node.exe"
        return $true 
    }
    return $false
}

if (!(Check-Node)) {
    Write-Host "❌ Node.js not found. Attempting to deploy Portable Node.js..." -ForegroundColor Yellow
    
    $nodeZipUrl = "https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip"
    $nodeZipFile = "$env:TEMP\node_portable.zip"
    
    try {
        Write-Host "📥 Downloading Portable Node.js (this might take a moment)..." -ForegroundColor Cyan
        (New-Object Net.WebClient).DownloadFile($nodeZipUrl, $nodeZipFile)
        
        Write-Host "📦 Extracting Node.js..." -ForegroundColor Cyan
        if (Test-Path $portableNodeDir) { Remove-Item -Recurse -Force $portableNodeDir }
        Expand-Archive -Path $nodeZipFile -DestinationPath "$env:TEMP\node_temp" -Force
        
        # GitHub/Node ZIPs have a subfolder
        $innerFolder = Get-ChildItem -Path "$env:TEMP\node_temp" -Directory | Select-Object -First 1
        Move-Item -Path "$($innerFolder.FullName)\*" -Destination "$PWD" -Force
        
        if (Test-Path "$PWD\node.exe") {
            $script:nodeExe = "$PWD\node.exe"
            $env:PATH = "$PWD;" + $env:PATH
            # Unblock all files to prevent Windows SmartScreen blocks
            Get-ChildItem -Path "$PWD" -Recurse | Unblock-File -ErrorAction SilentlyContinue
            Write-Host "✅ Portable Node.js ready and files unblocked!" -ForegroundColor Green
        }
        
        Remove-Item $nodeZipFile
        Remove-Item -Recurse -Force "$env:TEMP\node_temp"
    } catch {
        Write-Host "❌ Failed to deploy Portable Node.js. Error: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit
    }
}

# 2. Install dependencies
Write-Host "`n📦 Installing npm dependencies..." -ForegroundColor Yellow
if ($script:nodeExe -ne "node") {
    # If using portable node, find npm.cmd
    $npmCmd = "$PWD\npm.cmd"
    if (Test-Path $npmCmd) {
        & $npmCmd install
    } else {
        # Fallback to internal CLI if cmd missing
        $npmCli = "$PWD\node_modules\npm\bin\npm-cli.js"
        if (Test-Path $npmCli) {
            & $script:nodeExe $npmCli install
        } else {
            Write-Host "❌ Could not find npm. Please install manually." -ForegroundColor Red
        }
    }
} else {
    npm install
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ npm install failed." -ForegroundColor Yellow
}

# 3. Start the application
Write-Host "`n🌟 Starting the control panel..." -ForegroundColor Green
Write-Host "-------------------------------------------------"
Write-Host "Please wait for the Cloudflare Tunnel to initialize..." -ForegroundColor Cyan
Write-Host "-------------------------------------------------`n"

# Enable Debug for cloudflared output
$env:DEBUG = "true"
& $script:nodeExe server/index.js

# Handle errors
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Application stopped with error code $LASTEXITCODE" -ForegroundColor Red
}
Read-Host "`nPress Enter to close this window..."

