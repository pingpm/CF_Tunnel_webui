const express = require('express');
const { bin, install } = require('cloudflared');
const cors = require('cors');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const app = express();
const PORT = process.env.PORT || 11122;
const DATA_FILE = path.join(__dirname, 'data.json');

app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, '../client')));

// Store for active tunnels
const activeTunnels = new Map();
let adminTunnelUrl = '';
let db = { mappings: [] };

// Load DB
if (fs.existsSync(DATA_FILE)) {
    try {
        db = JSON.parse(fs.readFileSync(DATA_FILE));
    } catch (e) {
        console.error('Failed to load DB:', e);
    }
}

function saveDb() {
    fs.writeFileSync(DATA_FILE, JSON.stringify(db, null, 2));
}

/**
 * Start a Cloudflare Quick Tunnel
 */
function startTunnel(localPort, id = null) {
    return new Promise((resolve, reject) => {
        const absoluteBin = path.resolve(bin);
        console.log(`🚀 Starting tunnel for port ${localPort} using binary: ${absoluteBin}`);
        
        if (!fs.existsSync(absoluteBin)) {
            return reject(new Error(`Binary not found at ${absoluteBin}`));
        }

        const stats = fs.statSync(absoluteBin);
        console.log(`📊 Binary size: ${stats.size} bytes`);
        if (stats.size === 0) {
            return reject(new Error(`Binary at ${absoluteBin} is empty (0 bytes).`));
        }

        // cloudflared tunnel --url http://localhost:PORT
        // Use shell: true on Windows to prevent 'spawn UNKNOWN' errors
        const tunnelProcess = spawn(absoluteBin, ['tunnel', '--url', `http://localhost:${localPort}`], {
            shell: process.platform === 'win32'
        });
        
        let urlDetected = false;
        let url = '';

        tunnelProcess.stderr.on('data', (data) => {
            const output = data.toString();
            // Trycloudflare URLs usually look like: https://something.trycloudflare.com
            const match = output.match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);
            if (match && !urlDetected) {
                url = match[0];
                urlDetected = true;
                console.log(`✅ Tunnel URL for port ${localPort}: ${url}`);
                resolve({ process: tunnelProcess, url });
            }
            
            if (process.env.DEBUG) {
                console.log(`[cloudflared ${localPort}] ${output}`);
            }
        });

        tunnelProcess.on('exit', (code) => {
            console.log(`ℹ️ Tunnel for port ${localPort} exited with code ${code}`);
            if (id) {
                const mapping = db.mappings.find(m => m.id === id);
                if (mapping) mapping.status = 'stopped';
                activeTunnels.delete(id);
                saveDb();
            }
        });

        tunnelProcess.on('error', (err) => {
            console.error(`❌ Tunnel error for port ${localPort}:`, err);
            if (!urlDetected) reject(err);
        });

        // Timeout if no URL in 30s
        setTimeout(() => {
            if (!urlDetected) {
                try { tunnelProcess.kill(); } catch(e) {}
                reject(new Error('Tunnel startup timeout - Could not detect URL in output'));
            }
        }, 30000);
    });
}

// API Routes
app.get('/api/status', (req, res) => {
    res.json({
        adminUrl: adminTunnelUrl,
        port: PORT,
        activeCount: activeTunnels.size
    });
});

app.get('/api/tunnels', (req, res) => {
    const list = db.mappings.map(m => ({
        ...m,
        status: activeTunnels.has(m.id) ? 'running' : 'stopped',
        url: activeTunnels.get(m.id)?.url || null
    }));
    res.json(list);
});

app.post('/api/tunnels', async (req, res) => {
    const { name, localPort } = req.body;
    if (!localPort) return res.status(400).json({ error: 'Port is required' });

    const id = Date.now().toString();
    const newMapping = { id, name: name || `Port ${localPort}`, localPort, status: 'starting', createdAt: new Date() };
    db.mappings.push(newMapping);
    saveDb();

    try {
        const { process, url } = await startTunnel(localPort, id);
        activeTunnels.set(id, { process, url });
        
        const mapping = db.mappings.find(m => m.id === id);
        if (mapping) {
            mapping.status = 'running';
            saveDb();
        }
        
        res.json({ id, url });
    } catch (err) {
        console.error(err);
        const mapping = db.mappings.find(m => m.id === id);
        if (mapping) {
            mapping.status = 'failed';
            saveDb();
        }
        res.status(500).json({ error: `Failed to start tunnel: ${err.message}` });
    }
});

app.delete('/api/tunnels/:id', (req, res) => {
    const { id } = req.params;
    const tunnelInfo = activeTunnels.get(id);
    
    if (tunnelInfo) {
        try { tunnelInfo.process.kill(); } catch(e) {}
        activeTunnels.delete(id);
    }
    
    db.mappings = db.mappings.filter(m => m.id !== id);
    saveDb();
    res.json({ success: true });
});

// Handle binary installation with Mirror support
async function installBinary() {
    if (fs.existsSync(bin)) return;

    console.log('📦 Cloudflare binary not found. Preparing install...');
    
    // Attempt 1: Default installer from npm package
    try {
        console.log('尝试从官方源下载 (Attempting official download)...');
        // Set a timeout or catch error
        await install(bin);
        console.log('✅ Cloudflare binary installed via official source.');
        return;
    } catch (err) {
        console.warn('⚠️  官方源下载失败或超时，正在尝试加速镜像 (Official download failed, trying mirror)...');
    }

    // Attempt 2: Mirror fallback (China friendly)
    try {
        const platform = process.platform;
        const arch = process.arch;
        let binaryName = '';

        if (platform === 'win32') {
            binaryName = arch === 'x64' ? 'cloudflared-windows-amd64.exe' : 'cloudflared-windows-386.exe';
        } else if (platform === 'darwin') {
            binaryName = 'cloudflared-darwin-amd64.tgz'; // package normally handles tgz, but we need the bin
            // Darwin is usually okay with official, but if we are here, we might need a special handler
            // For simplicity, let's focus on Linux/Windows mirrors
        } else if (platform === 'linux') {
            binaryName = arch === 'x64' ? 'cloudflared-linux-amd64' : (arch === 'arm64' ? 'cloudflared-linux-arm64' : 'cloudflared-linux-386');
        }

        if (!binaryName || platform === 'darwin') {
             throw new Error('Unsupported platform for mirror download or Darwin detected');
        }

        const mirrorUrl = `https://ghproxy.net/https://github.com/cloudflare/cloudflared/releases/latest/download/${binaryName}`;
        console.log(`📥 从加速镜像下载 (Downloading from mirror): ${mirrorUrl}`);
        
        const axios = require('axios');
        const response = await axios({
            method: 'get',
            url: mirrorUrl,
            responseType: 'stream'
        });

        const writer = fs.createWriteStream(bin);
        response.data.pipe(writer);

        await new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });

        if (platform !== 'win32') {
            fs.chmodSync(bin, '755');
        }
        console.log('✅ Cloudflare binary installed via mirror.');
    } catch (err) {
        console.error('❌ 所有下载方式均失败 (All download attempts failed):', err.message);
        console.log('💡 请手动下载云端二进制文件并放入提示的文件夹中。');
        process.exit(1);
    }
}

// Start Admin Tunnel and Server
async function init() {
    // 1. Ensure binary exists
    await installBinary();

    app.listen(PORT, async () => {
        console.log(`Control Panel Server running on http://localhost:${PORT}`);
        
        try {
            const { url } = await startTunnel(PORT);
            adminTunnelUrl = url;
            console.log('\n=================================================');
            console.log('🚀 Cloudflare Tunnel Control Panel is ONLINE!');
            console.log(`🔗 Access Link: ${url}`);
            console.log('=================================================\n');
        } catch (err) {
            console.error('❌ Failed to start Admin Tunnel:', err.message);
            console.log('\n⚠️  Control panel is only available locally at http://localhost:' + PORT);
        }
    });
}

init();


