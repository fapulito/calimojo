/**
 * Client-side WebSocket utility for Mojo Poker
 * This provides browser-compatible WebSocket functionality
 */

class WebSocketClient {
  /**
   * Create a new WebSocket connection
   * @param {string} url - WebSocket server URL
   * @param {Object} options - Connection options
   * @param {string[]} [options.protocols] - Subprotocols
   */
  constructor(url, options = {}) {
    this.url = url;
    this.options = options;
    this.ws = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 1000; // Start with 1 second delay
    this.eventHandlers = {
      open: [],
      message: [],
      close: [],
      error: []
    };
  }

  /**
   * Connect to WebSocket server
   */
  connect() {
    try {
      // Use browser's native WebSocket constructor
      this.ws = new WebSocket(this.url, this.options.protocols);

      this.ws.onopen = (event) => {
        this.reconnectAttempts = 0; // Reset on successful connection
        this.reconnectDelay = 1000; // Reset delay
        this.emit('open', event);
      };

      this.ws.onmessage = (event) => {
        try {
          // Try to parse JSON, fall back to raw data
          let data;
          try {
            data = JSON.parse(event.data);
          } catch (e) {
            data = event.data;
          }
          this.emit('message', data);
        } catch (error) {
          console.error('Error processing WebSocket message:', error);
          this.emit('error', new Error('Message processing failed'));
        }
      };

      this.ws.onclose = (event) => {
        this.emit('close', event);
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
          this.scheduleReconnect();
        }
      };

      this.ws.onerror = (error) => {
        this.emit('error', error);
      };

    } catch (error) {
      console.error('WebSocket connection error:', error);
      this.emit('error', error);
      this.scheduleReconnect();
    }
  }

  /**
   * Schedule reconnection with exponential backoff
   */
  scheduleReconnect() {
    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    setTimeout(() => {
      console.log(`Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);
      this.connect();
    }, delay);
  }

  /**
   * Send data through WebSocket
   * @param {Object|string} data - Data to send
   */
  send(data) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      console.warn('WebSocket is not connected');
      return false;
    }

    try {
      const message = typeof data === 'object' ? JSON.stringify(data) : data;
      this.ws.send(message);
      return true;
    } catch (error) {
      console.error('Error sending WebSocket message:', error);
      this.emit('error', error);
      return false;
    }
  }

  /**
   * Close WebSocket connection
   * @param {number} [code] - Close code
   * @param {string} [reason] - Close reason
   */
  close(code = 1000, reason = 'Normal closure') {
    if (this.ws) {
      this.ws.close(code, reason);
    }
    this.reconnectAttempts = this.maxReconnectAttempts; // Prevent reconnect
  }

  /**
   * Add event listener
   * @param {string} event - Event name (open, message, close, error)
   * @param {Function} callback - Callback function
   */
  on(event, callback) {
    if (this.eventHandlers[event]) {
      this.eventHandlers[event].push(callback);
    }
    return this;
  }

  /**
   * Remove event listener
   * @param {string} event - Event name
   * @param {Function} callback - Callback function to remove
   */
  off(event, callback) {
    if (this.eventHandlers[event]) {
      this.eventHandlers[event] = this.eventHandlers[event].filter(
        cb => cb !== callback
      );
    }
    return this;
  }

  /**
   * Emit event to all listeners
   * @param {string} event - Event name
   * @param {*} data - Event data
   */
  emit(event, data) {
    this.eventHandlers[event].forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error(`Error in ${event} handler:`, error);
      }
    });
  }

  /**
   * Check if connection is active
   * @returns {boolean}
   */
  isConnected() {
    return this.ws && this.ws.readyState === WebSocket.OPEN;
  }

  /**
   * Get current connection state
   * @returns {string}
   */
  getReadyState() {
    if (!this.ws) return 'UNINSTANTIATED';
    const states = ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'];
    return states[this.ws.readyState];
  }
}

/**
 * Create a WebSocket connection (convenience function)
 * @param {string} url - WebSocket server URL
 * @param {Object} options - Connection options
 * @returns {WebSocketClient}
 */
export function createWebSocketClient(url, options = {}) {
  return new WebSocketClient(url, options);
}

/**
 * Poker-specific WebSocket client with game protocol
 */
export class PokerWebSocketClient extends WebSocketClient {
  constructor(url, options = {}) {
    super(url, {
      ...options,
      protocols: ['poker-v1']
    });
  }

  /**
   * Send game action
   * @param {string} action - Game action type
   * @param {Object} data - Action data
   */
  sendGameAction(action, data = {}) {
    return this.send({
      type: 'game_action',
      action: action,
      ...data,
      timestamp: Date.now()
    });
  }

  /**
   * Join a game
   * @param {number} gameId - Game ID
   * @param {number} userId - User ID
   */
  joinGame(gameId, userId) {
    return this.send({
      type: 'join_game',
      gameId: gameId,
      userId: userId
    });
  }

  /**
   * Leave a game
   * @param {number} gameId - Game ID
   * @param {number} userId - User ID
   */
  leaveGame(gameId, userId) {
    return this.send({
      type: 'leave_game',
      gameId: gameId,
      userId: userId
    });
  }
}

// Export for use in client-side code
export default WebSocketClient;