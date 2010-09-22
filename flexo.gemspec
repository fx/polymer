# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.required_rubygems_version = '>= 1.3.6'

  # The following four lines are automatically updates by the "gemspec"
  # rake task. It it completely safe to edit them, but using the rake task
  # is easier.
  s.name              = 'flexo'
  s.version           = '1.0.0.beta.2'
  s.date              = '2010-09-22'
  s.rubyforge_project = 'flexo'

  # You may safely edit the section below.

  s.platform     = Gem::Platform::RUBY
  s.authors      = ['Anthony Williams']
  s.email        = ['hi@antw.me']
  s.homepage     = 'http:/github.com/antw/flexo'
  s.summary      = 'Creates sprites for web applications'
  s.description  = 'Flexo simplifies the creation of sprite images for ' \
                   'web applications, while also generating nifty Sass ' \
                   'mixins. CSS files are available for non-Sass users,' \
                   'along with a directory-watcher and Rack middleware ' \
                   'to make development a breeze.'

  s.rdoc_options     = ['--charset=UTF-8']
  s.extra_rdoc_files = %w[History.md LICENSE README.md]

  s.executables  = ['flexo']
  s.require_path = 'lib'

  s.add_runtime_dependency     'rmagick',  '>= 2.13'
  s.add_runtime_dependency     'thor',     '>= 0.14.0'
  s.add_development_dependency 'rspec',    '>= 2.0.0.beta.19'
  s.add_development_dependency 'cucumber', '>= 0.8.5'
  s.add_development_dependency 'haml',     '>= 3.0.18'
  s.add_development_dependency 'ronn',     '>= 0.7.3'

  # The manifest is created by the "gemspec" rake task. Do not edit it
  # directly; your changes will be wiped out when you next run the task.

  # = MANIFEST =
  s.files = %w[
    Gemfile
    History.md
    LICENSE
    README.md
    Rakefile
    bin/flexo
    flexo.gemspec
    lib/flexo.rb
    lib/flexo/cache.rb
    lib/flexo/cli.rb
    lib/flexo/core_ext.rb
    lib/flexo/css_generator.rb
    lib/flexo/deviant_finder.rb
    lib/flexo/dsl.rb
    lib/flexo/optimisation.rb
    lib/flexo/project.rb
    lib/flexo/sass_generator.rb
    lib/flexo/source.rb
    lib/flexo/sprite.rb
    lib/flexo/templates/flexo.tt
    lib/flexo/templates/sass_mixins.erb
    lib/flexo/templates/sources/one/book.png
    lib/flexo/templates/sources/one/box-label.png
    lib/flexo/templates/sources/one/calculator.png
    lib/flexo/templates/sources/one/calendar-month.png
    lib/flexo/templates/sources/one/camera.png
    lib/flexo/templates/sources/one/eraser.png
    lib/flexo/templates/sources/two/inbox-image.png
    lib/flexo/templates/sources/two/magnet.png
    lib/flexo/templates/sources/two/newspaper.png
    lib/flexo/templates/sources/two/television.png
    lib/flexo/templates/sources/two/wand-hat.png
    lib/flexo/templates/sources/two/wooden-box-label.png
    lib/flexo/version.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^spec\/.*\.rb/ }
end
