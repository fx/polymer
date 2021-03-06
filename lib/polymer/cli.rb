require 'fileutils'
require 'thor'

module Polymer
  class CLI < Thor

    include Thor::Actions

    class_option 'no-color', :type => :boolean, :default => false,
      :desc => 'Disable colours in output', :aliases => '--no-colour'

    def initialize(*args)
      super
      self.shell = Thor::Shell::Basic.new if options['no-color']
    end

    # --- bond ---------------------------------------------------------------

    desc 'bond [SPRITES]',
      'Creates the sprites specified by your .polymer or polymer.rb file'

    long_desc <<-DESC
      The bond task reads your project configuration and creates your shiny
      new sprites. If enabled, CSS and/or SCSS will also be written so as to
      make working with your sprites a little easier.

      You may specify exactly which sprites you want generated, otherwise
      Polymer will generate all sprites defined in your config file. Any
      sprite which has not changed since you last ran this command will not be
      re-generated unless you pass the --force option.
    DESC

    method_option :force, :type => :boolean, :default => false,
      :desc => 'Re-generates sprites whose sources have not changed'

    method_option :fast, :type => :boolean, :default => false,
      :desc => "Skip optimisation of images after they are generated"

    def bond(*sprites)
      project = find_project!

      # Determine which sprites we'll be working on.
      sprites = project.sprites.select do |sprite|
        if sprites.empty? or sprites.include?(sprite.name)
          # The user specified no sprites, or this sprite was requested.
          if project.cache.stale?(sprite) or options[:force]
            # Digest is different, user is forcing update or sprite file
            # has been deleted.
            project.cache.set(sprite)
          end
        end
      end

      # There's nothing to generate.
      return if sprites.empty?

      # Get on with it.
      sprites.each do |sprite|
        next unless sprite.save

        say_status('generated', sprite.name, :green)

        unless options[:fast]
          run_optimisation(sprite.save_path, sprite.name)

          # Store the cached image so that running polymer-optimise
          # skips this image.
          project.cache.set(sprite.save_path.relative_path_from(project.root))
        end
      end

      # Stylesheets.
      if SassGenerator.generate(project)
        say_status('written', 'Sass mixin', :green)
      end

      #process Processors::CSS,        project

      # Find sprites with deviant-width sources.
      sprites.each do |sprite|
        if deviants = DeviantFinder.find_deviants(sprite)
          say DeviantFinder.format_ui_message(sprite, deviants)
        end
      end

      # Finish by writing the new cache.
      project.cache.write

      # Clean up temporary directories from data URI sprites.
      if project.data_uri_sprites.any?
        FileUtils.remove_entry_secure(project.tmpdir)
      end

    rescue Polymer::MissingSource, Polymer::TargetNotWritable => e
      say Polymer.compress_lines(e.message), :red
      exit 1
    end

    # --- help ---------------------------------------------------------------

    # Provides customised help information using the man pages.
    # Nod-of-the-hat to Bundler.
    def help(command = nil)
      page_map = {
        # Main manual page.
         nil         => 'polymer.1',
        'polymer'    => 'polymer.1',

        # Sub-commands.
        'init'       => 'polymer-init.1',
        'bond'       => 'polymer-bond.1',
        'optimise'   => 'polymer-optimise.1',
        'optimize'   => 'polymer-optimise.1',
        'position'   => 'polymer-position.1',

        # Configuration format.
        'polymer(5)' => 'polymer.5',
        'polymer.5'  => 'polymer.5',
        '.polymer'   => 'polymer.5',
        'polymer.rb' => 'polymer.5',
        'config'     => 'polymer.5'
      }

      if page_map.has_key?(command)
        root = File.expand_path('../man', __FILE__)

        if groff_available?
          groff = 'groff -Wall -mtty-char -mandoc -Tascii'
          pager = ENV['MANPAGER'] || ENV['PAGER'] || 'more'

          Kernel.exec "#{groff} #{root}/#{page_map[command]} | #{pager}"
        else
          puts File.read("#{root}/#{page_map[command]}.txt")
        end
      else
        super
      end
    end

    # --- init ---------------------------------------------------------------

    desc 'init', 'Creates a new Polymer project in the current directory'

    long_desc <<-DESC
      In order to use Polymer, a .polymer configuration file must be created.
      The init task creates a sample configuration, and also adds a couple of
      example source images to demonstrate how to use Polymer to create your
      own sprite images.
    DESC

    method_option :sprites, :type => :string, :default => 'public/images',
      :desc => 'Default location to which generated sprites are saved'

    method_option :sources, :type => :string, :default => '<sprites>/sprites',
      :desc => 'Default location of source images'

    method_option 'no-examples', :type => :boolean, :default => false,
      :desc => "Disables copying of example source files"

    method_option :windows, :type => :boolean, :default => false,
      :desc => 'Create polymer.rb instead of .polymer for easier editing on ' \
               'Windows systems.'

    def init
      if File.exists?('.polymer')
        say 'A .polymer file already exists in this directory.', :red
        exit 1
      end

      project_dir = Pathname.new(Dir.pwd)

      config = {
        :sprites => options[:sprites],
        :sources => options[:sources].gsub(/<sprites>/, options[:sprites]),
        :windows => options[:windows]
      }

      filename  = options[:windows] ? 'polymer.rb' : '.polymer'
      polymerfile = project_dir + filename

      template 'polymer.tt', polymerfile, config

      # Clean up the template.
      contents = polymerfile.read.gsub(/\n{3,}/, "\n\n")
      polymerfile.open('w') { |file| file.puts contents }

      unless options['no-examples']
        directory 'sources',  project_dir + config[:sources]
      end

      say_status '', '-------------------------'
      say_status '', 'Your project was created!'
    end

    # --- optimise -----------------------------------------------------------

    desc 'optimise PATHS', 'Optimises PNG images at the given PATHS'

    long_desc <<-DESC
      Given a path to an image (or multiple images), runs Polymer's optimisers
      on the image. Requires that the paths be images to PNG files. Image
      paths are relative to the current working directory.
    DESC

    method_option :force, :type => :boolean, :default => false,
      :desc => "Re-optimise images which haven't changed since the last " \
               "time they were optimised; has no effect unless in a " \
               "project directory."

    map 'optimize' => :optimise

    def optimise(*paths)
      dir = Pathname.new(Dir.pwd)

      # Try to use the project cache.
      begin
        project = find_project
        cache   = project.cache
      rescue Polymer::MissingProject
        project, cache = nil, Polymer::Cache.new
      end

      paths = paths.map do |path|
        path = dir + path
        # If given a directory, append a glob which recursively looks
        # for PNG files, otherwise use the path literally.
        path.directory? ? Pathname.glob(path + '**' + '*.png') : path.cleanpath
      end.flatten

      paths.each do |path|
        relative = path.relative_path_from(dir)

        if options[:force] or cache.stale?(relative)
          run_optimisation(path, relative)
          cache.set(relative)
        end
      end

      cache.clean! if project
      cache.write
    end

    # --- position -----------------------------------------------------------

    desc 'position SOURCE', 'Shows the position of a source within a sprite'

    long_desc <<-DESC
      The position task shows you the position of a source image within a
      sprite and also shows the appropriate CSS statement for the source
      should you wish to create your own CSS files.

      You may supply the name of a source image; if a source image with the
      same name exists in multiple sprites, the positions of each of them will
      be shown to you. If you want a particular source, you may instead
      provide a "sprite/source" pair.
    DESC

    def position(source)
      project = find_project!

      if source.index('/')
        # Full sprite/source pair given.
        sprite, source = source.split('/', 2)

        if project.sprite(sprite)
          sprites = [project.sprite(sprite)]
        else
          say "No such sprite: #{sprite}", :red
          exit 1
        end
      else
        # Only a source name was given.
        sprites = project.sprites
      end

      # Remove sprites which don't have a matching source.
      sprites.reject! { |sprite| not sprite.source(source) }
      say("No such source: #{source}") && exit(1) if sprites.empty?

      say ""

      sprites.each do |sprite|
        say "#{sprite.name}/#{source}: #{sprite.position_of(source)}px", :green
        say "    #{Polymer::CSSGenerator.background_statement(sprite, source)}"
        say "  - or -"
        say "    #{Polymer::CSSGenerator.position_statement(sprite, source)}"
        say ""
      end
    end

    # --- version ------------------------------------------------------------

    desc 'version', "Shows the version of Polymer you're using"
    map '--version' => :version

    def version
      say "Polymer #{Polymer::VERSION}"
    end

    private # ----------------------------------------------------------------

    # Returns the Project for the current directory. Exits with a message if
    # no project could be found.
    #
    # @return [Polymer::Project]
    #
    def find_project!
      find_project
    rescue Polymer::MissingProject
      say Polymer.compress_lines(<<-ERROR), :red
        Couldn't find a Polymer project in the current directory, or any of
        the parent directories. Run "polymer init" if you want to create a new
        project here.
      ERROR
      exit 1
    end

    # Trys to find a project, and raises if one is not available.
    #
    # @return [Polymer::Project]
    #
    def find_project
      Polymer::DSL.load Polymer::Project.find_config(Dir.pwd)
    end

    # Runs optimisation on a given +path+.
    #
    # @param [Pathname] path
    #   Path to the file to optimise.
    # @param [String] name
    #   The name of the "thing" being optimised. This is the value shown to
    #   the user, and allows removal of the path prefix, or use of a sprite
    #   name.
    #
    def run_optimisation(path, name)
      # Ensure the file is a PNG.
      unless path.to_s =~ /\.png/
        say_status 'skipped', "#{name} - not a PNG", :yellow
        return
      end

      before = path.size
      say "  optimising  #{name} "
      reduction = Polymer::Optimisation.optimise_file(path)

      if reduction > 0
        saved = '- saved %.2fkb (%.1f' %
          [reduction.to_f / 1024, (reduction.to_f / before) * 100]
        say_status "\r\e[0K   optimised", "#{name} #{saved}%)", :green
      else
        say_status "\r\e[0K   optimised", "#{name} - no savings", :green
      end
    end

    # Returns if the current machine has groff available.
    #
    # @return [Boolean]
    #
    def groff_available?
      require 'rbconfig'

      if RbConfig::CONFIG["host_os"] =~ /(msdos|mswin|djgpp|mingw)/
        `which groff 2>NUL`
      else
        `which groff 2>/dev/null`
      end

      $? == 0
    end

    def self.source_root
      File.expand_path(File.join(File.dirname(__FILE__), 'templates'))
    end

    # Temporary -- until the next Thor release.
    def self.banner(task, namespace = nil, subcommand = false)
      super.gsub(/^.*polymer/, 'polymer')
    end

  end # CLI
end # Polymer
