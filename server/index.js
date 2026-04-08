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
        console.log(`🚀 Starting tunnel for port ${localPort}...`);
        
        // cloudflared tunnel --url http://localhost:PORT
        const tunnelProcess = spawn(bin, ['tunnel', '--url', `http://localhost:${localPort}`]);
        
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

// Start Admin Tunnel and Server
async function init() {
    // 1. Ensure binary exists
    if (!fs.existsSync(bin)) {
        console.log('📦 Cloudflare binary not found. Downloading...');
        try {
            await install(bin);
            console.log('✅ Cloudflare binary installed successfully.');
        } catch (err) {
            console.error('❌ Failed to install cloudflared binary:', err.message);
            process.exit(1);
        }
    }

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


