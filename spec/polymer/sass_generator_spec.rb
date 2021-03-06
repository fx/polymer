require 'spec_helper'

describe Polymer::SassGenerator do
  subject { Polymer::SassGenerator }

  # --- generate -------------------------------------------------------------

  it { should respond_to(:generate) }

  describe '.generate' do
    before(:each) do
      use_helper!
    end

    context 'with default settings, one sprite and two sources' do
      before(:each) do
        write_source 'fry/one'
        write_source 'fry/two'

        @result = Polymer::SassGenerator.generate(project)

        @sass = path_to_file('public/stylesheets/sass/_polymer.sass')
      end

      it_should_behave_like 'a Sass generator'

      it 'should include conditionals for each sprite' do
        contents = @sass.read
        contents.should include('if $source == "fry/one"')
        contents.should include('if $source == "fry/two"')
      end

      describe 'the generated mixins' do
        it 'should correctly position the first source' do
          sass_to_css(@sass, 'polymer("fry/one")').should \
            include('background: url(/images/fry.png) 0px 0px no-repeat')

          sass_to_css(@sass, 'polymer-position("fry/one")').should \
            include('background-position: 0px 0px')
        end

        it 'should correctly position the second source' do
          sass_to_css(@sass, 'polymer("fry/two")').should \
            include('background: url(/images/fry.png) 0px -40px no-repeat')

          sass_to_css(@sass, 'polymer-position("fry/two")').should \
            include('background-position: 0px -40px')
        end

        it 'should apply x-offsets' do
          sass_to_css(@sass, 'polymer("fry/one", 5px)').should \
            include('background: url(/images/fry.png) 5px 0px no-repeat')

          sass_to_css(@sass, 'polymer-position("fry/one", 5px)').should \
            include('background-position: 5px 0px')
        end

        it 'should apply y-offsets' do
          # -20px (source one) - 20px (padding) - 10px (third arg) = -50px
          sass_to_css(@sass, 'polymer("fry/two", 0px, -10px)').should \
            include('background: url(/images/fry.png) 0px -50px no-repeat')

          sass_to_css(@sass, 'polymer-position("fry/two", 0px, -10px)').should \
            include('background-position: 0px -50px')
        end
      end # the generated mixins
    end # with default settings, one sprite and two sources

    context 'with default settings and two sprites' do
      before(:each) do
        write_source 'fry/one'
        write_source 'leela/one'

        @result = Polymer::SassGenerator.generate(project)

        @sass = path_to_file('public/stylesheets/sass/_polymer.sass')
      end

      it_should_behave_like 'a Sass generator'

      it 'should include conditionals for each sprite' do
        contents = @sass.read
        contents.should include('if $source == "fry/one"')
        contents.should include('if $source == "leela/one"')
      end

      describe 'the generated mixins' do
        it 'should correctly style sources in the first sprite' do
          sass_to_css(@sass, 'polymer("fry/one")').should \
            include('background: url(/images/fry.png) 0px 0px no-repeat')

          sass_to_css(@sass, 'polymer-position("fry/one")').should \
            include('background-position: 0px 0px')
        end

        it 'should correctly style sources in the second sprite' do
          sass_to_css(@sass, 'polymer("leela/one")').should \
            include('background: url(/images/leela.png) 0px 0px no-repeat')

          sass_to_css(@sass, 'polymer-position("leela/one")').should \
            include('background-position: 0px 0px')
        end
      end # the generated mixins
    end # with default settings and two sprites

    context 'with a custom URL setting' do
      before(:each) do
        write_config <<-CONFIG
          config.url "/right/here/:name.png"

          sprites "sources/:name/*" => "sprites/:name.png"
        CONFIG

        write_source 'fry/one'

        @result = Polymer::SassGenerator.generate(project)
        @sass = path_to_file('public/stylesheets/sass/_polymer.sass')
      end

      it_should_behave_like 'a Sass generator'

      it 'should set the correct image URL' do
        sass_to_css(@sass, 'polymer("fry/one")').should \
          include("url(/right/here/fry.png)")
      end
    end # with a custom URL setting

    context 'with a data URI sprite' do
      before(:each) do
        write_config <<-CONFIG
          sprites "sources/:name/*" => :data_uri
        CONFIG

        write_source 'fry/one'
        write_source 'fry/two'

        # We use @project here since each call to +project+ creates a new
        # project instance, which results in the temporary path used by
        # data URI sprites being changed.
        @project = project

        # Data URI sprites are written to a temporary path. Place an empty
        # file there.
        @sprite_path = @project.sprites.first.save_path
        @sprite_path.dirname.mkpath
        @sprite_path.open('w') { |f| f.puts("a" * 128) }

        @result = Polymer::SassGenerator.generate(@project)
        @sass = path_to_file('public/stylesheets/sass/_polymer.sass')
      end

      after(:each) do
        directory = @project.sprites.first.save_path.dirname
        FileUtils.remove_entry_secure(directory) if directory.directory?
      end

      it_should_behave_like 'a Sass generator'

      it 'should not set an image URL' do
        sass_to_css(@sass, 'polymer("fry/one")').should_not \
          include('background: url(/images/fry.png)')
      end

      it 'should add the contents of the sprite as base64' do
        data = [('a' * 128) + "\n"].pack('m').gsub(/\n/, '')

        sass_to_css(@sass, 'polymer("fry/one")').should \
          include("background: url(data:image/png;base64,#{data})")
      end

      it 'should add the selector to the data class selector' do
        sass_to_css(@sass, 'polymer("fry/one")').should \
          include(".fry_data, .rule")
      end

      it 'should correctly position the sprite' do
        sass_to_css(@sass, 'polymer("fry/one")').should \
          include('background-position: 0px 0px')

        sass_to_css(@sass, 'polymer("fry/two")').should \
          include('background-position: 0px -40px')
      end

      it 'should keep track of existing URIs' do
        @sprite_path.unlink

        lambda { Polymer::SassGenerator.generate(project) }.should_not \
          change { @sass.read }
      end
    end # with a data URI sprite

    context 'with Sass disabled' do
      before(:each) do
        write_config <<-CONFIG
          config.sass false

          sprites "sources/:name/*" => "sprites/:name.png"
        CONFIG
      end

      it 'should return false' do
        Polymer::SassGenerator.generate(project).should be_false
      end
    end # with Sass disabled

  end # .generate

end
