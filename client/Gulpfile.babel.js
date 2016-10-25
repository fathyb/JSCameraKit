import gulp from 'gulp'
import babel from 'gulp-babel'
import typescript from 'gulp-typescript'
import merge from 'merge2'

const ts = typescript.createProject('tsconfig.json')

gulp.task('typescript', () => {
	const pipe = ts.src().pipe(ts())

	return merge([
		pipe.dts.pipe(gulp.dest('build/dts')),
		pipe.js.pipe(gulp.dest('build/es6'))
	])
})

gulp.task('babel', ['typescript'], () =>
	gulp.src('build/es6/**/*.js')
		.pipe(babel())
		.pipe(gulp.dest('build/es5'))
)

gulp.task('build', ['typescript', 'babel'])
gulp.task('default', ['build'])