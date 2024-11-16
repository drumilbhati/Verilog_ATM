let ws = new WebSocket('ws://localhost:8080');
let currentPin = '';
let cardInserted = false;

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    updateDisplay(data);
};

function updateDisplay(data) {
    document.getElementById('stateDisplay').textContent = data.state;
    if (data.balance) {
        document.getElementById('balanceDisplay').textContent = 
            `Balance: $${data.balance.toFixed(2)}`;
    }
    if (data.error) {
        document.getElementById('messageDisplay').textContent = data.error;
    }
}

function appendPin(num) {
    if (currentPin.length < 4) {
        currentPin += num;
        document.getElementById('pinDisplay').textContent = 
            '*'.repeat(currentPin.length);
    }
}

function clearPin() {
    currentPin = '';
    document.getElementById('pinDisplay').textContent = '****';
}

function enter() {
    ws.send(JSON.stringify({
        type: 'pin',
        value: currentPin
    }));
    clearPin();
}

function toggleCard() {
    cardInserted = !cardInserted;
    ws.send(JSON.stringify({
        type: 'card',
        value: cardInserted ? 1 : 0
    }));
    document.getElementById('cardBtn').textContent = 
        cardInserted ? 'Remove Card' : 'Insert Card';
}