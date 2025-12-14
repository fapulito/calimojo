import { NextApiRequest, NextApiResponse } from 'next'
import { WebSocketServer } from 'ws'

// WebSocket server instance
let wss

/**
 * Handle incoming API requests: accept GET requests, upgrade to WebSocket when requested, or return endpoint information.
 *
 * Responds with 405 for non-GET methods. If the request's `Upgrade` header equals `'websocket'`, delegates the upgrade to `handleWebSocket`. For regular GET requests, returns a JSON payload describing the WebSocket endpoint and supported protocol(s).
 * @param {import('next').NextApiRequest} req - Incoming Next.js API request.
 * @param {import('next').NextApiResponse} res - Next.js API response used to send HTTP responses or perform the WebSocket upgrade.
 */
export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  // Handle WebSocket upgrade
  if (req.headers.upgrade === 'websocket') {
    return handleWebSocket(req, res)
  }

  // For HTTP requests, return information
  return res.status(200).json({
    message: 'WebSocket endpoint',
    status: 'active',
    supportedProtocols: ['poker-v1']
  })
}

/**
 * Upgrade an incoming HTTP request to a WebSocket connection and ensure a module-level WebSocketServer is initialized.
 *
 * Initializes the singleton WebSocketServer on first use and sets up connection, message, close, and error handlers,
 * then performs the HTTP -> WebSocket handshake for the provided request/response.
 *
 * @param {import('next').NextApiRequest} req - The incoming Next.js API request to upgrade.
 * @param {import('next').NextApiResponse} res - The Next.js API response whose socket is used to complete the upgrade.
 */
function handleWebSocket(req: NextApiRequest, res: NextApiResponse) {
  // Initialize WebSocket server if not already done
  if (!wss) {
    wss = new WebSocketServer({ noServer: true })

    wss.on('connection', (ws, req) => {
      console.log('New WebSocket connection')

      ws.on('message', (message) => {
        console.log('Received:', message.toString())
        // Handle poker game messages here
      })

      ws.on('close', () => {
        console.log('WebSocket connection closed')
      })

      ws.on('error', (error) => {
        console.error('WebSocket error:', error)
      })
    })
  }

  // Upgrade the connection
  wss.handleUpgrade(req, res.socket, Buffer.alloc(0), (ws) => {
    wss.emit('connection', ws, req)
  })
}

/**
 * Create and open a WebSocket client connected to the given URL.
 * @param {string} url - The WebSocket server URL to connect to.
 * @returns {Promise<WebSocket>} The connected `WebSocket` instance when the connection is established, rejects with the connection error otherwise.
 */
export function createWebSocketClient(url: string) {
  return new Promise((resolve, reject) => {
    try {
      const ws = new WebSocket(url)

      ws.onopen = () => {
        console.log('WebSocket connection established')
        resolve(ws)
      }

      ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        reject(error)
      }

      ws.onclose = () => {
        console.log('WebSocket connection closed')
      }

    } catch (error) {
      console.error('WebSocket creation error:', error)
      reject(error)
    }
  })
}