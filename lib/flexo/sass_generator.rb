module Flexo
  class SassGenerator

    TEMPLATE = Pathname.new(__FILE__).dirname + 'templates/sass_mixins.erb'

    # Given a project, generates a Sass stylesheet which can can be included
    # into your own Sass stylesheets, simplifying use of the sprite images
    # generated by Flexo.
    #
    # @param [Flexo::Project] project
    #   The project instance for which to generate a Sass stylesheet.
    #
    # @return [Boolean]
    #   Returns true if the stylesheet was generated and saved to the location
    #   specified by the project, or false if the project disables generation
    #   of Sass.
    #
    def self.generate(project)
      return false unless project.sass

      if project.sass.to_s[-5..-1] == '.sass'
        project.sass.dirname.mkpath
        save_to = project.sass
      else
        project.sass.mkpath
        save_to = project.sass + '_flexo.sass'
      end

      File.open(save_to, 'w') do |file|
        file.puts ERB.new(File.read(TEMPLATE), nil, '<>').result(binding)
      end

      true
    end # self.generate

  end # SassGenerator
end # Flexo
