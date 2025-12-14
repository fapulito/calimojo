const { WebSocketServer } = require('ws');

// WebSocket server instance
let wss;

module.exports = function handler(req, res) {
  // Handle WebSocket upgrade
  if (req.headers.upgrade === 'websocket') {
    return handleWebSocketUpgrade(req, res);
  }

  // For HTTP requests, return information
  return res.status(200).json({
    message: 'WebSocket endpoint',
    status: 'active',
    supportedProtocols: ['poker-v1']
  });
};

/**
 * Upgrade an incoming HTTP request to a WebSocket connection and attach handlers for connection lifecycle and incoming messages.
 *
 * Initializes a module-scoped WebSocketServer (noServer: true) if not already created, attaches handlers that parse JSON messages,
 * respond to a `join_game` message with a `game_ready` payload, acknowledge other messages, and send an `error` message for invalid JSON.
 * Finally, performs the WebSocket upgrade using the response socket and emits the `connection` event.
 *
 * @param {import('http').IncomingMessage} req - The HTTP request to upgrade.
 * @param {import('http').ServerResponse} res - The HTTP response whose socket will be used for the upgrade.
 */
function handleWebSocketUpgrade(req, res) {
  // Initialize WebSocket server if not already done
  if (!wss) {
    wss = new WebSocketServer({ noServer: true });

    wss.on('connection', (ws, req) => {
      console.log('New WebSocket connection established');

      ws.on('message', (message) => {
        console.log('Received WebSocket message:', message.toString());
        try {
          const data = JSON.parse(message.toString());

          // Handle different message types
          if (data.type === 'join_game') {
            console.log(`User ${data.userId} joining game ${data.gameId}`);
            ws.send(JSON.stringify({
              type: 'game_ready',
              message: 'Game 3 is ready! In a full implementation, you would now be connected to the poker table via WebSocket.',
              gameId: data.gameId,
              userId: data.userId
            }));
          } else {
            ws.send(JSON.stringify({
              type: 'acknowledgment',
              message: 'Message received',
              originalMessage: data
            }));
          }
        } catch (error) {
          console.error('Error processing WebSocket message:', error);
          ws.send(JSON.stringify({
            type: 'error',
            message: 'Invalid message format'
          }));
        }
      });

      ws.on('close', () => {
        console.log('WebSocket connection closed');
      });

      ws.on('error', (error) => {
        console.error('WebSocket error:', error);
      });
    });
  }

  // Upgrade the connection
  wss.handleUpgrade(req, res.socket, Buffer.alloc(0), (ws) => {
    wss.emit('connection', ws, req);
  });
}