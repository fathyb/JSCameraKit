import {Resolution, Position} from './camera'

export module ResolutionConverter {
	export function toSize(resolution: Resolution): [number, number] {
		let width: number, height: number
		
		switch(resolution) {
			case Resolution.HD1920x1080:
				width = 1920
				height = 1080
				break
			case Resolution.HD1280x720:
				width = 1280
				height = 720
				break
			case Resolution.SD640x480:
			default:
				width = 640
				height = 480
				break
		}

		return [width, height]	
	}

	export function parse(resolution: string): Resolution {
		switch(resolution) {
			case '480p':
				return Resolution.SD640x480
			case '720p':
				return Resolution.HD1280x720
			case '1080p':
				return Resolution.HD1920x1080
			default:
				throw new Error(`Unknown resolution "${resolution}"`)
		}
	}
}

export module PositionConverter {
	export function stringify(position: Position): string {
		switch(position) {
			case Position.Back:
				return 'back'
			case Position.Front:
				return 'front'
			case Position.Default:
			default:
				return 'default'
		}
	} 

	export function parse(position: string): Position {
		switch(position) {
			case 'front':
				return Position.Front
			case 'back':
				return Position.Back
			case 'default':
				return Position.Default
			default:
				throw new Error(`Unknown position "${position}".`)
		}
	}
}