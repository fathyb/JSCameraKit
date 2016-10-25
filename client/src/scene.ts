import {getRectangle, newTexture} from './glutils'
import {GLProgram} from './program'

export interface WebGLEffect {
	fragment: string
	name: string
	fragmentHead?: string
}

export class WebGLYUVScene {
	private width: number
	private height: number
	private rotated: boolean = false
	private canvas: HTMLCanvasElement
	private gl: WebGLRenderingContext
	private prog: GLProgram
	private effect: string = 'none'
	public effects: WebGLEffect[] = [{
		name: 'Grayscale',
		fragment: 'rgb = vec3(texture2D(uYTexture, vTexCoord).r);'
	}, {
		name: 'None',
		fragment: ''
	}, {
		name: 'Sepia',
		fragment: `
			rgb = vec3(
				(rgb.r * 0.393) + (rgb.g * 0.769) + (rgb.b * 0.189),
    			(rgb.r * 0.349) + (rgb.g * 0.686) + (rgb.b * 0.168),    
    			(rgb.r * 0.272) + (rgb.g * 0.534) + (rgb.b * 0.131)
			);
		`
	}, {
		name: 'Polaroid',
		fragment: `
			rgb *= mat3(
				1.438,  -.062, -.062,
	            -.122,  1.378, -.122,
	            -.016,  -.016, 1.483
			);
		`
	}, {
		name: 'CRT',
		fragment: `
			vec2 uv = vTexCoord.xy;// / uResolution.xy;
			//uv.y = 1.0 - uv.y; // flip tex
			vec2 crtCoords = crt(uv, 3.2);

			// shadertoy has tiling textures. wouldn't be needed
			// if you set up your tex params properly
			if (crtCoords.x < 0.0 || crtCoords.x > 1.0 || crtCoords.y < 0.0 || crtCoords.y > 1.0) {
				rgb = vec3(0.);
			}
			else {
				// Split the color channels
				rgb = sampleSplit(crtCoords);

				vec2 screenSpace = crtCoords * uResolution.xy;
				rgb = scanline(screenSpace, rgb);
			}
		`,
		fragmentHead: `
			vec3 scanline(vec2 coord, vec3 screen) {
				screen.rgb -= sin((coord.y + (uTime * 29.0))) * 0.02;
				return screen;
			}

			vec2 crt(vec2 coord, float bend) {
				// put in symmetrical coords
				coord = (coord - 0.5) * 2.0;

				coord *= 1.1;	

				// deform coords
				coord.x *= 1.0 + pow((abs(coord.y) / bend), 2.0);
				coord.y *= 1.0 + pow((abs(coord.x) / bend), 2.0);

				// transform back to 0.0 - 1.0 space
				coord  = (coord / 2.0) + 0.5;

				return coord;
			}

			vec3 sampleSplit(vec2 coord) {
				vec3 frag;
				float coef = .005 * sin(uTime);

				frag.r = getColor(vec2(coord.x - coef, coord.y)).r;
				frag.g = getColor(vec2(coord.x, coord.y)).g;
				frag.b = getColor(vec2(coord.x + coef, coord.y)).b;
				return frag;
			}
		`
	}]

	private yTexture: WebGLTexture
	private uvTexture: WebGLTexture

	private vertex: string = `
		precision mediump float;

		attribute vec2 aPosition;
		attribute vec2 aTexCoord;

		uniform vec2 uResolution;
		uniform vec2 uRotation;
		uniform vec2 uScale;

		varying vec2 vTexCoord;

		void main() {
			vec2 zeroToOne = aPosition / uResolution;
			vec2 zeroToTwo = zeroToOne * 2.;
			vec2 clipSpace = zeroToTwo - 1.;

			vec2 position = clipSpace * vec2(1, -1);

			vec2 rotated = position * uRotation.yy;
			rotated.x += position.y * uRotation.x;
			rotated.y -= position.x * uRotation.x;

			gl_Position = vec4(
				//position.x * uRotation.y + position.y * uRotation.x,
				//position.y * uRotation.y - position.x * uRotation.x,
				rotated * uScale,
			0, 1);

			vTexCoord = aTexCoord;
		}
	`

	private fragment: string = `
		precision mediump float;

		uniform sampler2D uYTexture;
		uniform sampler2D uUVTexture;

		uniform float uTime;
		uniform vec2 uResolution;
		varying highp vec2 vTexCoord;

		mat3 rgbMat = mat3(
			      1,       1,      1,
			      0, -.18732, 1.8556,
            1.57481, -.46813,      0
		);

		vec3 getColor(vec2 position) {
			vec3 yuv = vec3(
				texture2D(uYTexture, position).r,
				texture2D(uUVTexture, position).ar - vec2(.5, .5)
			);

			return (rgbMat * yuv).bgr;
		}

		${this.effects.map(
			effect => `uniform bool uUseEffect${effect.name};\n${effect.fragmentHead || ''}`
		).join('\n')}

		void main() {
			vec3 rgb = getColor(vTexCoord);

			${this.effects.map(effect =>
				`if(uUseEffect${effect.name}) { ${effect.fragment}; }`
			).join('\n')}

			gl_FragColor = vec4(rgb, 1);
		}
	`

	public setCanvas(canvas: HTMLCanvasElement): void {
		this.canvas = canvas

		try {
			this.gl = canvas.getContext('webgl')! as WebGLRenderingContext
		}
		catch(e) {
			this.gl = canvas.getContext('experimental-webgl')! as WebGLRenderingContext
		}

		this.initGL()
	}

	public getEffect(): string {
		return this.effect
	}

	public setEffect(name: string): void {
		const {gl} = this
		const effectRe = /^uUseEffect/
		let effect: WebGLEffect

		for(let obj of this.effects) {
			if(obj.name.toLocaleLowerCase() == name.toLocaleLowerCase()) {
				effect = obj
				break
			}
		}

		if(!effect)
			throw new Error(`Effect "${name}" not found."`)
		
		this.effect = name.toLocaleLowerCase()

		Object
			.keys(this.prog.locations.uniforms)
			.filter(key => effectRe.test(key))
			.forEach(key => {
				const effectName = key.replace(effectRe, '')
				const location = this.prog.locations.uniforms[key]

				if(effectName.toLocaleLowerCase() == name.toLocaleLowerCase())
					gl.uniform1i(location, 1)
				else
					gl.uniform1i(location, 0)
			})
	}
	public setSize(width: number, height: number, rotated = true, mirror = true): void {
		const {gl, canvas, prog} = this
		const {uResolution, uRotation, uScale} = prog.locations.uniforms

		if(rotated)
			[width, height] = [height, width]

		this.rotated = rotated
		this.width = width
		this.height = height

		canvas.width = width
		canvas.height = height

		prog.setAttribute('aPosition', 2, getRectangle(0, 0, width, height))

		gl.uniform2f(uResolution, width, height)

		if(rotated)
			gl.uniform2f(uRotation, 1, 0)
		else
			gl.uniform2f(uRotation, 0, 1)
		
		if(mirror)
			gl.uniform2f(uScale, -1, 1)
		else
			gl.uniform2f(uScale, 1, 1)

		gl.viewport(0, 0, width, height)
	}

	public clear(color: [number, number, number, number] = [0, 0, 0, 1]): void {
		const {gl} = this
		const [r, g, b, a] = color

		gl.clearColor(r, g, b, a)
		gl.clear(gl.COLOR_BUFFER_BIT)
	}
	
	public draw(): void {
		const {gl} = this

		gl.uniform1f(this.prog.locations.uniforms['uTime'], performance.now() / 1000)
		gl.drawArrays(gl.TRIANGLES, 0, 6)
	}

	public initGL(force: boolean = false): this {
		if(!force && this.prog)
			return
		
		const {canvas, gl, fragment, vertex} = this
		const program = new GLProgram(gl, fragment, vertex).build()
		const glProg = program.program

		this.prog = program

		gl.useProgram(glProg)

		program.setAttribute('aTexCoord', 2, [
			0, 0,
			1, 0,
			0, 1,
			0, 1,
			1, 0,
			1, 1
		])

		const yTexture = newTexture(gl)
		const uvTexture = newTexture(gl)

		gl.activeTexture(gl.TEXTURE0)
		gl.bindTexture(gl.TEXTURE_2D, yTexture)
		gl.uniform1i(gl.getUniformLocation(glProg, 'uYTexture'), 0)

		gl.activeTexture(gl.TEXTURE1)
		gl.bindTexture(gl.TEXTURE_2D, uvTexture)
		gl.uniform1i(gl.getUniformLocation(glProg, 'uUVTexture'), 1)

		this.yTexture = yTexture
		this.uvTexture = uvTexture

		console.log('GL ok')

		return this
	}

	public uploadTextures(yBuffer: Uint8Array, uvBuffer: Uint8Array): void {
		const {gl, yTexture, uvTexture, width, height, rotated} = this
		const [x, y] = rotated ? [height, width] : [width, height]

		gl.bindTexture(gl.TEXTURE_2D, yTexture)
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.LUMINANCE,
			x, y,
			0,
			gl.LUMINANCE,
			gl.UNSIGNED_BYTE,
			yBuffer
		)

		gl.bindTexture(gl.TEXTURE_2D, uvTexture)
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.LUMINANCE_ALPHA,
			x / 2, y / 2,
			0,
			gl.LUMINANCE_ALPHA,
			gl.UNSIGNED_BYTE,
			uvBuffer
		)
	}
}