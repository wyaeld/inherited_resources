require File.dirname(__FILE__) + '/test_helper'

class Book; end
class Folder; end

class BooksController < InheritedResources::Base
  actions :index, :show
  defaults :route_prefix => nil
end

class ReadersController < InheritedResources::Base
  actions :all, :except => [ :edit, :update ]
end

class FoldersController < InheritedResources::Base
end

# For belongs_to tests
class GreatSchool
end

class Professor
  def self.human_name; 'Professor'; end
end

BELONGS_TO_OPTIONS = {
  :parent_class => GreatSchool,
  :instance_name => :great_school,
  :finder => :find_by_title!,
  :param => :school_title
}

class SchoolsController < InheritedResources::Base
  has_scope :by_city
  has_scope :featured, :boolean => true, :only => :index, :key => :by_featured
  has_scope :limit, :default => 10, :except => :index, :on => :anything
end

class ProfessorsController < InheritedResources::Base
  belongs_to :school, BELONGS_TO_OPTIONS
end


class ActionsClassMethodTest < ActiveSupport::TestCase
  def test_actions_are_undefined
    action_methods = BooksController.send(:action_methods)
    assert_equal 2, action_methods.size

    ['index', 'show'].each do |action|
      assert action_methods.include? action
    end
  end

  def test_actions_are_undefined_when_except_option_is_given
    action_methods = ReadersController.send(:action_methods)
    assert_equal 5, action_methods.size

    ['index', 'new', 'show', 'create', 'destroy'].each do |action|
      assert action_methods.include? action
    end
  end
end


class DefaultsClassMethodTest < ActiveSupport::TestCase
  def test_resource_class_is_set_to_nil_when_resource_model_cannot_be_found
    assert_nil ReadersController.send(:resource_class)
  end

  def test_defaults_are_set
    assert Folder, FoldersController.send(:resource_class)
    assert :folder, FoldersController.send(:resources_configuration)[:self][:instance_name]
    assert :folders, FoldersController.send(:resources_configuration)[:self][:collection_name]
  end

  def test_defaults_can_be_overwriten
    BooksController.send(:defaults, :resource_class => String, :instance_name => 'string', :collection_name => 'strings')

    assert String, BooksController.send(:resource_class)
    assert :string, BooksController.send(:resources_configuration)[:self][:instance_name]
    assert :strings, BooksController.send(:resources_configuration)[:self][:collection_name]

    BooksController.send(:defaults, :class_name => 'Fixnum', :instance_name => :fixnum, :collection_name => :fixnums)

    assert String, BooksController.send(:resource_class)
    assert :string, BooksController.send(:resources_configuration)[:self][:instance_name]
    assert :strings, BooksController.send(:resources_configuration)[:self][:collection_name]
  end

  def test_defaults_raises_invalid_key
    assert_raise ArgumentError do
      BooksController.send(:defaults, :boom => String)
    end
  end

  def test_url_helpers_are_recreated_when_defaults_change
    InheritedResources::UrlHelpers.expects(:create_resources_url_helpers!).returns(true).once
    BooksController.send(:defaults, :instance_name => 'string', :collection_name => 'strings')
  end
end


class BelongsToClassMethodTest < ActionController::TestCase
  tests ProfessorsController

  def setup
    GreatSchool.expects(:find_by_title!).with('nice').returns(mock_school(:professors => Professor))

    @controller.stubs(:resource_url).returns('/')
    @controller.stubs(:collection_url).returns('/')
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_index
    Professor.stubs(:find).returns([mock_professor])
    get :index, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_show
    Professor.stubs(:find).returns(mock_professor)
    get :show, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_new
    Professor.stubs(:build).returns(mock_professor)
    get :new, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_edit
    Professor.stubs(:find).returns(mock_professor)
    get :edit, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_create
    Professor.stubs(:build).returns(mock_professor(:save => true))
    post :create, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_update
    Professor.stubs(:find).returns(mock_professor(:update_attributes => true))
    put :update, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  def test_expose_the_resquested_school_with_chosen_instance_variable_on_destroy
    Professor.stubs(:find).returns(mock_professor(:destroy => true))
    delete :destroy, :school_title => 'nice'
    assert_equal mock_school, assigns(:great_school)
  end

  protected

    def mock_school(stubs={})
      @mock_school ||= mock(stubs)
    end

    def mock_professor(stubs={})
      @mock_professor ||= mock(stubs)
    end
end

class BelongsToErrorsTest < ActiveSupport::TestCase
  def test_belongs_to_raise_errors_with_invalid_arguments
    assert_raise ArgumentError do
      ProfessorsController.send(:belongs_to)
    end

    assert_raise ArgumentError do
      ProfessorsController.send(:belongs_to, :nice, :invalid_key => '')
    end
  end

  def test_belongs_to_raises_an_error_when_multiple_associations_are_given_with_options
    assert_raise ArgumentError do
      ProfessorsController.send(:belongs_to, :arguments, :with_options, :parent_class => Professor)
    end
  end

  def test_url_helpers_are_recreated_just_once_when_belongs_to_is_called_with_block
    InheritedResources::UrlHelpers.expects(:create_resources_url_helpers!).returns(true).once
    ProfessorsController.send(:belongs_to, :school, BELONGS_TO_OPTIONS) do
      belongs_to :association
    end
  ensure
    ProfessorsController.send(:parents_symbols=, [:school])
  end

  def test_url_helpers_are_recreated_just_once_when_belongs_to_is_called_with_multiple_blocks
    InheritedResources::UrlHelpers.expects(:create_resources_url_helpers!).returns(true).once
    ProfessorsController.send(:belongs_to, :school, BELONGS_TO_OPTIONS) do
      belongs_to :association do
        belongs_to :nested
      end
    end
  ensure
    ProfessorsController.send(:parents_symbols=, [:school])
  end

  def test_belongs_to_raises_an_error_when_multiple_associations_are_given_with_block
    assert_raise ArgumentError, "You cannot define multiple associations and give a block to belongs_to." do
      ProfessorsController.send(:belongs_to, :school, :another, BELONGS_TO_OPTIONS) do
        belongs_to :association
      end
    end
  ensure
    ProfessorsController.send(:parents_symbols=, [:school])
  end
end
class HasScopeClassMethods < ActiveSupport::TestCase

  def test_scope_configuration_is_stored_as_hashes
    config = SchoolsController.send(:scopes_configuration)
    assert config.key?(:school)
    assert config.key?(:anything)

    assert config[:school].key?(:by_city)
    assert config[:school].key?(:featured)
    assert config[:anything].key?(:limit)

    assert_equal config[:school][:by_city], { :key => :by_city, :only => [], :except => [] }
    assert_equal config[:school][:featured], { :key => :by_featured, :only => [ :index ], :except => [], :boolean => true }
    assert_equal config[:anything][:limit], { :key => :limit, :except => [ :index ], :only => [], :default => 10 }
  end

  def test_scope_on_value_is_guessed_inside_belongs_to_blocks
    ProfessorsController.send(:has_scope, :limit)
    ProfessorsController.send(:belongs_to, :school, BELONGS_TO_OPTIONS) do
      has_scope :featured
      has_scope :another, :on => :professor
    end

    config = ProfessorsController.send(:scopes_configuration)
    assert config[:school].key?(:featured)
    assert config[:professor].key?(:limit)
    assert config[:professor].key?(:another)
  ensure
    ProfessorsController.send(:scopes_configuration=, {})
  end

  def test_scope_is_loaded_from_another_controller
    ProfessorsController.send(:load_scopes_from, SchoolsController)
    config = ProfessorsController.send(:scopes_configuration)

    assert config.key?(:school)
    assert config.key?(:anything)

    assert config[:school].key?(:by_city)
    assert config[:school].key?(:featured)
    assert config[:anything].key?(:limit)
  ensure
    ProfessorsController.send(:scopes_configuration=, {})
  end

  def test_scope_is_deep_merged_from_another_controller
    config = ProfessorsController.send(:scopes_configuration)

    ProfessorsController.send(:has_scope, :featured, :on => :school)
    assert_equal config[:school][:featured], { :key => :featured, :only => [ ], :except => [] }

    ProfessorsController.send(:load_scopes_from, SchoolsController)
    assert config.key?(:school)
    assert config[:school].key?(:by_city)
    assert config[:school].key?(:featured)
    assert_equal config[:school][:featured], { :key => :by_featured, :only => [ :index ], :except => [], :boolean => true }
  end

  def test_scope_is_loaded_from_another_controller_with_on_specified
    ProfessorsController.send(:load_scopes_from, SchoolsController, :on => :school)
    config = ProfessorsController.send(:scopes_configuration)

    assert config.key?(:school)
    assert config[:school].key?(:by_city)
    assert config[:school].key?(:featured)

    assert !config.key?(:anything)
  ensure
    ProfessorsController.send(:scopes_configuration=, {})
  end

  def test_scope_is_loaded_from_another_controller_with_on_guessed
    ProfessorsController.send(:belongs_to, :school, BELONGS_TO_OPTIONS) do
      load_scopes_from SchoolsController
    end
    config = ProfessorsController.send(:scopes_configuration)

    assert config.key?(:school)
    assert config[:school].key?(:by_city)
    assert config[:school].key?(:featured)

    assert !config.key?(:anything)
  ensure
    ProfessorsController.send(:scopes_configuration=, {})
  end
end
