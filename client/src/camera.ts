import {WebGLYUVScene} from './scene'
import {WebSocketController} from './ctrl'
import {EventEmitter} from './eventemitter'
import {FPSMeter} from './fpsmeter'
import {PositionConverter, ResolutionConverter} from './converters'
import {time} from './utils'

export enum Resolution {
	SD640x480, HD1280x720, HD1920x1080
}

export enum Position {
	Default, Back, Front
}

//FPS60 only available on 1080p but
enum Framerate {
	FPS30, FPS60
}

export interface Configuration {
	resolution: Resolution
	position: Position
}

export interface ConfigureResponse {
	width: number
	height: number
	mirrored: boolean
	rotated: boolean
}

const Requests = {
	getConfiguration: 'get-configuration',
	stop: 'stop',
	ping: 'ping',
	configure: 'configure',
	changePosition: 'change-position',
	changeResolution: 'change-resolution',
	capturePhoto: 'capture-photo',
	needFrame: 'need-frame'
}

export class Camera extends EventEmitter {
	private fps = new FPSMeter()
	private webSocket = new WebSocketController()
	private scene = new WebGLYUVScene()
	private running = false
	private shouldDraw = false
	private animationFrame: number
	private configuration: Configuration = {
		resolution: Resolution.HD1280x720,
		position: Position.Back,
	}

	private timeLog = {
		changeResolution: -1,
		changePosition: -1
	}

	private  yBuffer: Uint8Array
	private uvBuffer: Uint8Array

	constructor() {
		super()

		this.webSocket.on('binary-message', data => {
			const buffer = new Uint8Array(data)
			const type = buffer[0]

			if(type == 0)
				this.yBuffer = buffer.subarray(1)
			else if(type == 1)
				this.uvBuffer = buffer.subarray(1)
			else
				throw new Error(`Unknown framebuffer type "${type}.`)
			
			if(this.yBuffer && this.uvBuffer) {
				this.scene.uploadTextures(this.yBuffer, this.uvBuffer)
				this.shouldDraw = true

				this.yBuffer = null
				this.uvBuffer = null
			}
		})
	}

	public setCanvas(canvas: HTMLCanvasElement): this {
		this.scene.setCanvas(canvas)

		return this
	}

	public async start(configuration: Configuration = this.configuration): Promise<void> {
		this.scene.initGL()
		
		await this.configure(configuration)

		this.running = true
		this.requestAnimationFrame()
	}

	public stop(): Promise<void> {
		this.running = false
		
		return this.webSocket.request<void>(Requests.stop)
	}

	public async ping(): Promise<void> {
		const timer = time('ping')

		await this.webSocket.request<void>(Requests.ping)
		
		timer()
	}

	public async configure(configuration: Configuration = this.configuration): Promise<any> {
		const resolution = ResolutionConverter.toSize(configuration.resolution).join('x')
		const position = PositionConverter.stringify(configuration.position)
		const data = await this.webSocket.request<ConfigureResponse>(Requests.configure, {resolution, position})

		this.configureGL(data)
	}

	public async changePosition(position: Position): Promise<void> {
		const now = performance.now()

		if((now - this.timeLog.changePosition) < 500)
			return
		
		console.log('Changing position')

		this.timeLog.changePosition = now

		const data = await this.webSocket.request<ConfigureResponse>(Requests.changePosition, PositionConverter.stringify(position))
		
		this.configureGL(data)
	}

	public async changeResolution(resolution: Resolution): Promise<ConfigureResponse> {
		const now = performance.now()

		if((now - this.timeLog.changeResolution) < 500)
			return this.getConfiguration()
		
		console.log('Changing resolution')

		this.timeLog.changeResolution = now
		
		const data = await this.webSocket.request<ConfigureResponse>(
			Requests.changeResolution, ResolutionConverter.toSize(resolution).join('x')
		)
		
		this.configureGL(data)

		return data 
	}

	public getConfiguration(): Promise<ConfigureResponse> {
		return this.webSocket.request<ConfigureResponse>(Requests.getConfiguration)
	}

	public capturePhoto(): Promise<void> {
		this.scene.clear()

		return this.webSocket.request<void>(Requests.capturePhoto)
	}

	private configureGL({width, height, rotated, mirrored}: ConfigureResponse): void {
		this.scene.setSize(width, height, rotated, mirrored)

		console.log(
			'Configured, width: %s, height: %s, mirrored: %s, rotated: %s',
			width, height, mirrored, rotated
		)
	}

	private requestCameraFrame(): void {
		this.webSocket.request<void>(Requests.needFrame)
	}

	private requestAnimationFrame(): this {
		if(this.animationFrame != null)
			cancelAnimationFrame(this.animationFrame)

		this.animationFrame = requestAnimationFrame(() => {
			if(this.shouldDraw) {
				this.fps.update()
				this.scene.draw()
				this.shouldDraw = false

				this.emit('fps', this.fps.fps)
			}

			this.animationFrame = null

			if(this.running)
				this.requestAnimationFrame()
					.requestCameraFrame()
		})

		return this
	}
}