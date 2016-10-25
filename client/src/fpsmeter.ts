export class FPSMeter {
	public fps: number
	private lastDraw: number
	
	public update(): void {
		const now = performance.now()
		const delta = (now - this.lastDraw) / 1000

		this.lastDraw = now
		this.fps = Math.floor(1 / delta)
	}
}