import * as net from 'net'

export async function isLoopbackAvailable(): Promise<boolean> {
  return new Promise((resolve) => {
    const server = net.createServer()
    server.on('error', () => resolve(false))
    server.listen(0, '127.0.0.1', () => {
      server.close(() => resolve(true))
    })
  })
}
