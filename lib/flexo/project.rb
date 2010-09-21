module Flexo
  # Represents a directory in which it is expected that there be a
  # configuration file, and source images.
  class Project
    DEFAULTS = {
      :sources => 'public/images/sprites',
      :sprites => 'public/images',
      :sass    => 'public/stylesheets/sass',
      :to      => "public/images/:name.png",
      :url     => "/images/:name.png",
      :padding => 20
    }

    # Stores all the paths the project needs.
    Paths = Struct.new(:root, :config, :sass, :url, :cache)

    # Returns the Paths instance for the project.
    #
    # @return [Flexo::Project::Paths]
    #
    attr_reader :paths

    # Returns an Array containing all the Sprites defined in the project.
    #
    # @return [Array<Flexo::Sprite>]
    #
    attr_reader :sprites

    # Returns the amount of space to be used between each source image when
    # saving sprites.
    #
    # @return [Integer]
    #
    attr_reader :padding

    # Creates a new Project instance.
    #
    # Note that +new+ does no validation of the given paths: it expects them
    # to be correct. If you're not sure of the exact paths, use +Project.find+
    # instead.
    #
    # @param [String, Pathname] config_path
    #   Path to the config file.
    #
    def initialize(config_path)
      config_path = Pathname.new(config_path)
      config      = YAML.load_file(config_path)
      root_path   = config_path.dirname

      # Sass path may be a string representing a path, or `false`.
      sass_path = config.delete("config.sass") { DEFAULTS[:sass] }
      sass_path = sass_path.is_a?(String) ? root_path + sass_path : sass_path

      # Determine if the config path is a standard .flexo file, or a Windows
      # flexo.yml, and adjust the cache path accordinly.
      cache_path = config_path.to_s.gsub(/flexo(\.yml)?$/, 'flexo-cache\1')
      cache_path = Pathname.new(cache_path)

      @paths = Paths.new(
        root_path, config_path, sass_path,
        config.delete('config.url') { DEFAULTS[:url] },
        cache_path
      )

      @padding = (config.delete('config.padding') || 20).to_i

      # All remaining entries are sprite defintions.
      @sprites = config.map do |path, opts|
        Flexo::SpriteDefinition.new(self, path, opts).to_sprites
      end.flatten
    end

    # TEMPORARY
    #
    # Used by the new Ruby DSL to create a project.
    #
    # @param [Pathname] root_path
    #   Path to the root of the Flexo project. The .flexo config should reside
    #   in this directory.
    # @param [Array<Flexo::Sprite>] sprites
    #   An array of sprites which belong to the project.
    #
    def self.new2(root_path, sprites)
      allocate.instance_eval do
        @root    = root_path
        @sprites = sprites

        self
      end
    end

    # Returns a particular sprite identified by +name+.
    #
    # @param [String] name
    #   The name of the sprite to be retrieved.
    #
    # @return [Flexo::Sprite]
    #
    def sprite(name)
      sprites.detect { |sprite| sprite.name == name }
    end

    private # ================================================================

    # Extracts a configuration value from a configuration hash. If the value
    # exists, and is a string, it will be appended to the +root+ path.
    #
    # The configuration item will be _removed_ from the hash.
    #
    # @param [Hash]     config  The configuration Hash.
    # @param [Symbol]   key     The configuration key.
    # @param [Pathname] root    The project root path.
    #
    # @return [Pathname, false]
    #
    def extract_path_from_config(config, key, root)
      value = config.delete("config.#{key}") { DEFAULTS[key] }
      value.is_a?(String) ? root + value : value
    end

    # === Class Methods ======================================================

    class << self

      # Given a path to a directory, +find+ attempts to locate a suitable
      # configuration file by looking for a ".flexo" or "flexo.yml" file. If
      # no such file is found in the given directory, it ascends the directory
      # structure until one is found, or it runs out of paths to check.
      #
      # If given a path to a file, +find+ assumes that this file is the config
      # and simply returns it.
      #
      # @param [Pathname, String] path
      #   The path to the directory or confiration file.
      #
      # @return [Flexo::Project]
      #   Returns the Project representing the found configuration.
      #
      # @raise [MissingProject]
      #   Raised when no project directory could be found.
      #
      def find(path)
        new find_config(path)
      end

      # Given a path to a directory, +find_config+ attempts to locate a
      # suitable configuration file by looking for a ".flexo" or "flexo.rb"
      # file. If no such file is found in the given directory, it ascends the
      # directory structure until one is found, or it runs out of parent
      # directories to check.
      #
      # If given a path to a file, +find_config+ assumes that this file is the
      # config, and simply returns it as a Pathname.
      #
      # @param [Pathname, String] path
      #   The path to the directory or configuration file.
      #
      # @return [Pathname]
      #   The path to the found configuration.
      #
      # @raise [Flexo::MissingProject]
      #   Raised when +find_config+ could not find a suitable configuration
      #   file.
      #
      def find_config(path)
        path, config_path = Pathname.new(path).expand_path, nil
        return path if path.file?

        path.ascend do |directory|
          if (dot_flexo = directory + '.flexo').file?
            return dot_flexo
          elsif (flexo_rb = directory + 'flexo.rb').file?
            return flexo_rb
          end
        end

        raise MissingProject,
          "Flexo couldn't find a configuration file at `#{path.to_s}'"
      end

    end # class << self
  end # Project
end # Flexo
