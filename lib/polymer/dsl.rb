module Polymer
  # Provides the DSL used in .polymer files.
  #
  # In order to account for situations where global configuration may
  # appear after some sprites are defined, the DSL instance keeps track
  # of each defined sprite, but only resolves the settings for each
  # one once +to_project+ is called.
  #
  class DSL

    # Given a path to a file, reads and evaluates the contents as a DSL
    # definition.
    #
    # @param [Pathname] path
    #   Path to a .polymer file to be evaluated.
    #
    # @return [Polymer::Project]
    #   The project represented by the config file.
    #
    def self.load(path)
      dsl = new(path.dirname)
      dsl.instance_eval path.read.split('__END__').first, path.to_s, 1
      dsl.to_project
    end

    # Builds a project using the given block.
    #
    # The given DSL block will be run using +instance_eval+, thus no
    # parameters are given to the block.
    #
    # @param [Pathname] root
    #   When building a project using the DSL, rather than a .polymer file,
    #   you need to provide a path to the directory you want to serve as the
    #   Polymer root.
    #
    # @return [Polymer::Project]
    #   The project represented by the DSL.
    #
    # @example
    #
    #   Polymer::DSL.build('/path/to/project') do
    #     sprite 'sources/lurrr/*' => 'sprites/lurrr.png'
    #   end
    #
    def self.build(root, &block)
      file, line = caller.first.split(':')

      dsl = new(root)
      dsl.instance_eval &block
      dsl.to_project
    end

    # Creates a new DSL instance.
    #
    # @param [Pathname] root_path
    #   Path to the root of the Polymer project. The .polymer config should
    #   reside in this directory.
    #
    def initialize(root_path)
      @root    = root_path
      @sprites = []
      @config  = ProjectConfig.new
    end

    # Returns the configuration object. Used to set global options which
    # should either affect the whole project (css, sass), or used as a default
    # value for sprite settings (padding, url).
    #
    # @return [Polymer::DSL::Config]
    #
    attr_reader :config

    # Defines a sprite.
    #
    # Expects a single Hash as the parameter, where the hash should include
    # precisely one String key mapped to a String value, and any extra options
    # to be used when creating the sprite passed with Symbol keys.
    #
    # The String key should be a path -- relative to the .polymer file -- to
    # the source files to be used for the sprite, while the value is a path
    # indicating where the sprite should be saved (including filename).
    #
    # See the DEFINING SPRITES section of polymer(5) for more information.
    #
    # @param [Hash] definition
    #   A { String => String } pair, plus any additional options.
    #
    # @option definition [Integer] :padding (20)
    #   Sets the size of the transparent space to be inserted between each
    #   source image. Measured in pixels.
    # @option definition [String] :url ("/images/:filename")
    #   The URL at which the sprite can be requested by a browser. Used when
    #   generating stylesheets.
    #
    # @example
    #
    #   # Creates a sprite where the sources are in "path/to/sources" with the
    #   # generated sprite saved to "path/to/sprite.png", using 50px vertical
    #   # padding between each source image.
    #
    #   sprite "path/to/sources" => "path/to_sprite", :padding => 50
    #
    def sprite(definition)
      definition[:padding] = 0 if definition[:padding] == false

      # Find the source => sprite mapping.
      source, sprite = _extract_mapping(definition)

      # If the source contains a :name segment, it may define multiple sprites
      # depending on the directory structure.
      if source.to_s =~ /:name/
        if definition.has_key?(:name)
          # Can't have a :name segment and an explicit name option.
          raise Polymer::DslError,
            "Sprite '#{source} => #{sprite}' has both a :name path segment " \
            "and a :name option; please use only one."
        elsif sprite != :data_uri and sprite !~ /:name/
          raise Polymer::MissingName,
            "Sprite '#{source} => #{sprite}' requires a :name segment in " \
            "the sprite path."
        else
          _define_multiple_sprites(source, sprite, definition)
        end
      else
        _define_sprite(source, sprite, definition)
      end

      nil
    end

    alias_method :sprites, :sprite

    # Transforms the configuration -- and defined sprites -- into a Project.
    #
    # @return [Polymer::Project]
    #
    def to_project
      project_config = @config.to_h

      Project.new(@root, @sprites.map do |definition|
        _create_sprite(definition, project_config)
      end, project_config)
    end

    #######
    private
    #######

    # Given a sprite as defined in the config file, extracts the source path,
    # the sprite path, _destructively removes them from the Hash_, and returns
    # a two-element array with their values.
    #
    # @return [Array<String, String>] The source and sprite path.
    #
    def _extract_mapping(definition)
      unless source = definition.detect { |key, value| key.is_a?(String) }
        raise Polymer::MissingMap,
          'Sprite definition is missing a { source => sprite } pair.'
      end

      source
    end

    # Defines a single sprite.
    #
    # @param [String] sources
    #   The path at which Polymer should look for source images. If the path
    #   is a directory, Polymer will assume that any images within it are to
    #   be used as sources. Relative to +@root+.
    # @param [String] sprite
    #   The path, relative to +@root+ at which the generated sprite is to
    #   be saved.
    # @param [Hash] options
    #   Other options.
    #
    # @raise [Polymer::DuplicateName]
    #   Raised when the sprite uses a name which has been taken by an
    #   existing sprite.
    #
    def _define_sprite(sources, sprite, options)
      sources = @root + sources
      sprite  = @root + sprite unless sprite == :data_uri

      name = options[:name] || sprite.basename(sprite.extname).to_s

      if @sprites.detect { |definition| definition[:name] == name }
        raise DuplicateName,
          "You tried to create a sprite whose name is `#{name}', but a " \
          "sprite with this name has already been defined."
      end

      # Handle when a directory is given without a file-matcher.
      sources = sources + '*' if sources.directory?

      @sprites << options.merge(
        :name      => name,
        :sources   => Pathname.glob(sources),
        :save_path => sprite
      )
    end

    # Defines multiple sprites with a :name segment.
    #
    # @param [String] sources
    #   The path at which we can find sources.
    # @param [String] sprite
    #   The path at which the sprite is to be saved.
    # @param [Hash] options
    #   Other options.
    #
    def _define_multiple_sprites(sources, sprite, options)
      leading, trailing = sources.split(':name')

      Pathname.glob(@root + leading + '*').each do |entry|
        next unless entry.directory?

        sprite_opts = options.dup # Create a copy for each sprite.
        sprite_opts[:name] = entry.basename.to_s # Use directory as the name

        source_path = "#{leading}#{sprite_opts[:name]}#{trailing}"
        sprite_path = (sprite == :data_uri) ?
          :data_uri : sprite.gsub(/:name/, sprite_opts[:name])

        _define_sprite(source_path, sprite_path, sprite_opts)
      end
    end

    # Given a sprite definition, creates a final Sprite instance.
    #
    # @param [Hash] definition
    #   The sprite as defined; with options parsed by _define_sprites.
    # @param [Hash] project_config
    #   The global project configuration.
    #
    # @return [Polymer::Sprite]
    #
    def _create_sprite(definition, project_config)
      if definition[:save_path] == :data_uri and not project_config[:sass]
        raise DslError, "The `#{definition[:name]}' sprite wants to use a " \
                        "data URI, but you have disabled Sass"
      end

      unless definition[:save_path] == :data_uri
        url = definition.fetch(:url, project_config[:url]).dup
        url.gsub!(/:name/, definition[:name])
        url.gsub!(/:filename/, definition[:save_path].basename.to_s)
      end

      Polymer::Sprite.new \
        definition[:name],
        definition[:sources],
        definition[:save_path],
        definition.fetch(:padding, project_config[:padding]) || 0,
        url || ''
    end

    # Provides the DSL for the global configuration options.
    #
    # @private
    #
    class ProjectConfig
      ATTRIBUTES = %w( cache css padding url sass ).map(&:to_sym).freeze

      # Define the setter methods for each attribute. The setters are
      # sans-equals to provide a slightly more concise syntax.
      #
      ATTRIBUTES.each do |method|
        class_eval <<-RUBY
          def #{method}(value)           # def padding(value)
            @config[:#{method}] = value  #   @config[:padding] = value
          end                            # end
        RUBY
      end

      # Creates a new ProjectConfig. Sets the default values which are used in
      # the event that the user doesn't specify them.
      #
      def initialize
        @config = ATTRIBUTES.inject({}) do |memo, attribute|
          memo[attribute] = Polymer::Project::DEFAULTS[attribute]
          memo
        end
      end

      # Returns a hash containing each of the attribute values.
      #
      def to_h
        @config
      end
    end # ProjectConfig

  end # DSL
end # Polymer
