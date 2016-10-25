import {EventEmitter} from './eventemitter'

//const WebSocketRequest = 0xbadada
//const WebSocketRequestResponse = 0xdababa

export class WebSocketController extends EventEmitter {
	private webSocket: WebSocket
	private connectTimer = null
	private requestID = 0

	constructor() {
		super()

		this.on('message', msg => {
			if(typeof msg == 'string') {
				try {
					const json = JSON.parse(msg)

					return this.emit('json-message', json)
				}
				catch(e) {
					return this.emit('string-message', msg)
				}
			}
			else if(msg instanceof ArrayBuffer) {
				this.emit('binary-message', msg)
			}
		}).on('close', (close: CloseEvent) => {
			this.clear()

			if(this.connectTimer === null) {
				this.connectTimer = setTimeout(
					() => {
						this.connect().connectTimer = null
						console.log('connection lost, reconnecting...')
					}, 500
				)
			}
		}).connect()
	}

	public waitForSocket(timeout = 5000): Promise<any> {
		if(this.webSocket && this.webSocket.readyState == WebSocket.OPEN)
			return Promise.resolve()
		
		return this.once('open', timeout)
	}

	public connect(): this {
		this.clear()

		this.webSocket = new WebSocket('ws://localhost:6001', 'jsbridge-protocol')
		this.webSocket.onclose = evt => this.emit('close', evt)
		this.webSocket.onopen = evt => this.emit('open', evt)
		this.webSocket.onmessage = evt => this.emit('message', evt.data)
		this.webSocket.onerror = err => this.emit('error', err)

		this.webSocket.binaryType = 'arraybuffer'

		return this
	}

	public request<T>(request: string, data?: any): Promise<T> {
		return new Promise<T>(resolve => {
			const id = this.requestID++ // id should be an Int32

			const off = this.onOff('json-message', json => {
				if(parseInt(json.id) == id) {
					off()
					resolve(json.data)
				}
			})

			this.send(JSON.stringify({request, id, data}))
		})
	}

	public async send(data: any): Promise<void> {
		await this.waitForSocket()
		
		this.webSocket.send(data)
	}

	private clear() {
		if(this.webSocket) {
			this.webSocket.onclose = null
			this.webSocket.onopen = null
			this.webSocket.onmessage = null
			this.webSocket.onerror = null
			this.webSocket = null
		}
	}
}