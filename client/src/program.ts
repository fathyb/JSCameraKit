interface Shaders {
	fragment: WebGLShader
	vertex: WebGLShader
}
export interface Locations {
	uniforms: {
		[key: string]: WebGLUniformLocation
	}
	attributes: {
		[key: string]: number
	}
}
export class GLProgram {
	private prog: WebGLProgram
	private shaders: Shaders
	private loc: Locations = {
		uniforms: {},
		attributes: {}
	}

	constructor(
		private gl: WebGLRenderingContext,
		private fragment: string, private vertex: string
	) {
		this.prog = gl.createProgram()
	}

	public build(): this {
		const {fragment, vertex, gl, prog} = this

		this.shaders = {
			fragment: this.buildShader('fragment', fragment),
			vertex: this.buildShader('vertex', vertex)
		}

		gl.attachShader(prog, this.shaders.fragment)
		gl.attachShader(prog, this.shaders.vertex)

		gl.linkProgram(prog)

		if(!gl.getProgramParameter(prog, gl.LINK_STATUS))
			throw new Error(`Count not link the shader program!\n${gl.getProgramInfoLog(prog)}`)
		
		const attribs = gl.getProgramParameter(prog, gl.ACTIVE_ATTRIBUTES)

		for(let i = 0; i < attribs; i++) {
			const {name} = gl.getActiveAttrib(prog, i)

			this.loc.attributes[name] = gl.getAttribLocation(prog, name)
		}
		
		const unis = gl.getProgramParameter(prog, gl.ACTIVE_UNIFORMS)

		for(let i = 0; i < unis; i++) {
			const {name} = gl.getActiveUniform(prog, i)

			this.loc.uniforms[name] = gl.getUniformLocation(prog, name)
		}

		return this
	}

	public get locations(): Locations {
		return this.loc
	}
	public get program(): WebGLProgram {
		return this.prog
	}

	public setAttribute(name: string, size: number, buf: number[]): void {
		const {gl, locations} = this

		if(!(name in locations.attributes))
			throw new Error(`Cannot find attribute named "${name}"`)
		
		const location = this.locations.attributes[name]

		gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer())
		gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(buf), gl.STATIC_DRAW)

		gl.enableVertexAttribArray(location)
		gl.vertexAttribPointer(location, size, gl.FLOAT, false, 0, 0)
	}

	private buildShader(type: 'vertex'|'fragment', source: string): WebGLShader {
		const {gl} = this
		const shaderType = type == 'vertex' ? gl.VERTEX_SHADER : gl.FRAGMENT_SHADER
		const shader = gl.createShader(shaderType)

		gl.shaderSource(shader, source)
		gl.compileShader(shader)

		if(!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
			throw new Error(
				`Could not compile ${type} shader:\n\n${gl.getShaderInfoLog(shader)}`
			)
		}

		return shader
	}
}