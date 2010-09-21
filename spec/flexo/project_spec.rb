require 'spec_helper'

describe Flexo::Project do
  subject { Flexo::Project }

  # Class Methods ============================================================

  # --- find_config ----------------------------------------------------------

  it { should respond_to(:find_config) }

  describe '.find_config' do
    context 'when given a project root, with .flexo present' do
      before(:all) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.touch '.flexo'
      end

      it 'should return a path to .flexo' do
        path = Flexo::Project.find_config(@helper.project_dir)
        path.should == @helper.path_to_file('.flexo')
      end
    end # when given a project root, with .flexo present

    context 'when given a project root, with flexo.rb present' do
      before(:all) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.touch 'flexo.rb'
      end

      it 'should return a path to flexo.rb' do
        path = Flexo::Project.find_config(@helper.project_dir)
        path.should == @helper.path_to_file('flexo.rb')
      end
    end # when given a project root, with flexo.rb present

    context 'when given a project sub-dir, with .flexo in a parent' do
      before(:all) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.mkdir 'sub/sub'
        @helper.touch '.flexo'
      end

      it 'should return a path to .flexo' do
        path = Flexo::Project.find_config(@helper.project_dir + 'sub/sub')
        path.should == @helper.path_to_file('.flexo')
      end
    end # when given a project sub-dir, with .flexo in a parent

    context 'when given a project sub-dir, with flexo.rb in a parent' do
      before(:all) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.mkdir 'sub/sub'
        @helper.touch 'flexo.rb'
      end

      it 'should return a path to flexo.rb' do
        path = Flexo::Project.find_config(@helper.project_dir + 'sub/sub')
        path.should == @helper.path_to_file('flexo.rb')
      end
    end # when given a project sub-dir, with flexo.rb in a parent

    context 'when given a path to a file' do
      before(:all) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.touch '.flexo'
      end

      it 'should return a path to the file' do
        Flexo::Project.find_config(@helper.path_to_file('.flexo'))
      end
    end # when given a path to a file

    context 'when given an empty directory' do
      before(:all) do
        @helper = Flexo::Spec::ProjectHelper.new
      end

      it 'should raise an error' do
        running = lambda { Flexo::Project.find_config(@helper.project_dir) }
        running.should raise_error(Flexo::MissingProject)
      end
    end # when given an empty directory

    context 'when given an invalid path' do
      it 'should raise an error' do
        running = lambda { Flexo::Project.find_config('__invalid__') }
        running.should raise_error(Flexo::MissingProject)
      end
    end # when given an invalid path
  end

  # Instance Methods =========================================================

  it { should have_public_method_defined(:root) }
  it { should have_public_method_defined(:paths) }

  # --- sprites --------------------------------------------------------------

  it { should have_public_method_defined(:sprites) }

  describe '#sprites' do
    context "when the project has one sprite with two sources" do
      before(:each) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.write_simple_config
        @helper.write_source('sprite_one/one', 100, 25)
        @helper.write_source('sprite_one/two', 100, 25)
      end

      it 'should return an array with one element' do
        @helper.project.sprites.should have(1).sprite
      end

      it 'should have two sources in the sprite' do
        @helper.project.sprites.first.should have(2).sources
      end
    end # when the project has one sprite with two sources

    context "when the project has two sprites with 2/1 sources" do
      before(:each) do
        @helper = Flexo::Spec::ProjectHelper.new
        @helper.write_simple_config
        @helper.write_source('sprite_one/one',   100, 25)
        @helper.write_source('sprite_one/two',   100, 25)
        @helper.write_source('sprite_two/three', 100, 25)
      end

      it 'should return an array with two elements' do
        @helper.project.sprites.should have(2).sprite
      end

      it 'should have two sources in the first sprite' do
        @helper.project.sprite('sprite_one').should have(2).sources
      end

      it 'should have one source in the second sprite' do
        @helper.project.sprite('sprite_two').should have(1).sources
      end
    end # when the project has one sprite with two sources

  end

end
