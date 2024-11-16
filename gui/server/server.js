const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const port = 3000;

// Serve static files
app.use(express.static(path.join(__dirname, '../public')));

// Create WebSocket server
const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
    console.log('Client connected');

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            handleATMCommand(data, ws);
        } catch (error) {
            console.error('Error handling message:', error);
        }
    });
});

function handleATMCommand(data, ws) {
    // Path to your Verilog simulation executable
    const verilogPath = path.join(__dirname, '../../verilog/sim');
    
    switch(data.type) {
        case 'card':
            exec(`${verilogPath} +card=${data.value}`, handleVerilogResponse(ws));
            break;
        case 'pin':
            exec(`${verilogPath} +pin=${data.value}`, handleVerilogResponse(ws));
            break;
        // Add other commands
    }
}

function handleVerilogResponse(ws) {
    return (error, stdout, stderr) => {
        if (error) {
            console.error(`Verilog error: ${error}`);
            return;
        }
        ws.send(JSON.stringify({
            state: parseVerilogOutput(stdout)
        }));
    };
}

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});