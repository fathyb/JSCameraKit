export function time(name: string): () => void {
	const id = uniqueID(16).slice(0, 5)
	const timer = `${id}:${name}`

	console.time(timer)

	return () => console.timeEnd(timer)
}

export function uniqueID(base: number = 36): string {
	return Math.random().toString(base).replace(/^.*\./g, '')
}