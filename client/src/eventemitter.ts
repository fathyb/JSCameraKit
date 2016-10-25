export interface Listener {
	(...args: any[]): void
}

export class EventEmitter {
	private listeners = new Map<string, Listener[]>()

	public on(event: string, listener: Listener): this {
		if(!this.listeners.has(event))
			this.listeners.set(event, [])
		
		this.listeners.get(event).push(listener)

		return this
	}

	public onOff(event: string, listener: Listener): () => void {
		this.on(event, listener)

		return () => this.off(event, listener)
	}

	public once(event: string, timeout: number = -1): Promise<any[]> {
		return new Promise<any[]>((resolve, reject) => {
			let timer = -1

			if(timeout != -1)
				timer = setTimeout(() => reject(new Error(`Timout! Waited ${timeout}ms`)), timeout)
			
			const fn = (...args) => {
				this.off(event, fn)

				if(timer != -1)
					clearTimeout(timer)
				
				resolve(args)
			}
			
			this.on(event, fn)
		})
	}

	public emit(event: string, ...args: any[]): this {
		if(this.listeners.has(event)) {
			const listeners = this.listeners.get(event)

			listeners.forEach(listener => listener(...args))
		}

		return this
	}

	public off(event: string, listener: Listener): this {
		if(this.listeners.has(event)) {
			const listeners = this.listeners.get(event)
			const idx = listeners.indexOf(listener)

			if(idx != -1) {
				listeners.splice(idx, 1)

				return this
			}
		}

		throw new Error(`Calling EventEmitter.off('${event}', ...) with a unknown listener.`)
	}
}