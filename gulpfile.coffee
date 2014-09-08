gulp = require 'gulp'
watch = require 'gulp-watch'
jade = require 'gulp-jade'
coffee = require 'gulp-coffee'
sass = require 'gulp-ruby-sass'
rename = require 'gulp-rename'
uglify = require 'gulp-uglify'
jsonminify = require 'gulp-jsonminify'

gulp.task 'default', ->
  gulp.src('bower_components/underscore/underscore-min.js')
    .pipe(gulp.dest('dist/js'))
  gulp.src('bower_components/underscore/underscore-min.map')
    .pipe(gulp.dest('dist/js'))

  gulp.src('bower_components/backbone/backbone.js')
    .pipe(uglify())
    .pipe(rename('backbone-min.js'))
    .pipe(gulp.dest('dist/js'))

  gulp.src('bower_components/backbone.localStorage/backbone.localStorage-min.js')
    .pipe(gulp.dest('dist/js'))

  gulp.src('src/jade/index.jade')
    #.pipe(watch())
    .pipe(jade())
    .pipe(gulp.dest('dist'))

  gulp.src('src/sass/application.sass')
    #.pipe(watch())
    .pipe(sass style: 'compressed')
    .pipe(gulp.dest('dist/css'))

  gulp.src('src/coffee/application.coffee')
    #.pipe(watch())
    .pipe(coffee())
    .pipe(uglify())
    .pipe(gulp.dest('dist/js'))

  gulp.src('src/coffee/server.coffee')
    #.pipe(watch())
    .pipe(coffee())
    .pipe(uglify())
    .pipe(gulp.dest('./'))

  gulp.src('src/data/data.json')
    .pipe(jsonminify())
    .pipe(gulp.dest('dist/data'))
