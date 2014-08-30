gulp = require 'gulp'
watch = require 'gulp-watch'
jade = require 'gulp-jade'
coffee = require 'gulp-coffee'
sass = require 'gulp-ruby-sass'
uglify = require 'gulp-uglify'
jsonminify = require 'gulp-jsonminify'

copyVendorFiles = (vendorFiles) ->
  for type, files of vendorFiles
    files = [files] unless files instanceof Array
    for file in files
      gulp.src("vendor/#{type}/#{file}")
        .pipe(gulp.dest("dist/#{type}"))

gulp.task 'default', ->
  copyVendorFiles
    css: 'bootstrap.min.css'
    js: [
      'jquery-1.11.1.min.js'
      'bootstrap.min.js'
      'underscore-min.js'
      'backbone-min.js'
      'backbone.localStorage-min.js'
    ]
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
