const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 3000 });

var count = 0;

wss.on('connection', function connection(ws) {
  ws.on('message', function message(data) {
    console.log('received: %s', data);
    ws.send('something'+(++count));
  });

  ws.send('something');
});
