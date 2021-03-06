require 'forwardable'

# Add spec/ to the load path.
$LOAD_PATH.unshift File.expand_path('../../../spec', __FILE__)

# Loading the spec helper loads all of the test support files, and
# also the Polymer library itself.
require 'spec_helper'

# This Cucumber world wraps around the CommandRunner in order to provide
# some useful helper method.
class Polymer::Spec::CucumberWorld
  extend Forwardable

  # Path to the polymer executable.
  EXECUTABLE = Pathname.new(__FILE__).dirname.
                  expand_path + '../../bin/polymer'

  # The CommandRunner instance used by the world to run commands.
  attr_reader :command

  # A list of files whose attributes have been modified.
  attr_reader :chmods

  # Helpers which should be passed through to the command.
  def_delegators :command, :status, :stdout, :stderr

  def initialize
    @command = Polymer::Spec::CommandRunner.new
    @chmods  = {}
  end

  # Runs a command.
  #
  # @param [String] to_run
  #   The command to be run, exactly as it would be on the command line.
  # @param [String] dir
  #   An optional sub-directory in which to run the command.
  # @param [Block] block
  #   Yields the stdin.
  #
  # @return [Boolean]
  #   Returns true if the command exited with zero status, false if non-zero.
  #
  def run(to_run, dir = '', &block)
    if ! @no_fast and to_run =~ /polymer generate/ and to_run !~ /--fast/
      # When possible, run polymer generate with the --fast option to skip
      # time-intensive sprite optimisation.
      to_run += ' --fast'
    end

    @command.run(to_run, dir, &block)

    if @announce
      puts
      puts '--- STDOUT ---------------------------------'
      puts stdout.gsub(/\e/, '\\e')
      puts
      puts '--- STDERR ---------------------------------'
      puts stderr.gsub(/\e/, '\\e')
      puts
      puts '--------------------------------------------'
      puts
    end

    @command.status == 0
  end

  def compile_and_escape(string)
    Regexp.compile(Regexp.escape(string))
  end

  def combined_output
    stdout + (stderr == '' ? '' : "\n#{'-'*70}\n#{stderr}")
  end

  def create_default_project!
    self.class.create_default_project! @command.project_dir
  end

  # --- Class Methods --------------------------------------------------------

  # A sample project with a configuration only.
  def self.create_default_project!(to)
    unless defined? @default_project
      path = Pathname.new(Dir.mktmpdir)

      @default_project = Polymer::Spec::CommandRunner.new(path)
      @default_project.run \
        'polymer init --no-examples --sprites sprites --sources sources'
    end

    FileUtils.cp_r(@default_project.project_dir.to_s + '/.', to)
  end

  # Returns the default project or nil if one has not been used.
  def self.default_project
    @default_project
  end

end # Polymer::Spec::CucumberWorld

World do
  Polymer::Spec::CucumberWorld.new
end

Before '@announce' do
  @announce = true
end

Before '@polymer-optimise' do
  @no_fast = true
end

After do
  # Restore the attributes of any files which changed.
  chmods.each { |path, mode| Pathname.new(path).chmod(mode) }
end

# Always clean up temporary project directories once finished.
at_exit do
  Polymer::Spec::ProjectHelper.cleanup!

  default_project = Polymer::Spec::CucumberWorld.default_project
  default_project and default_project.cleanup!
end
