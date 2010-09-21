@flexo-generate
Feature: Sass mixin files

  In order to make Flexo awesome
  It should generate Sass mixins

  Scenario: Creating a Sass mixin with a sprite
    Given I have a default project
      And I have 1 source in public/images/sprites/fry
    When I run "flexo generate"
    Then the exit status should be 0
      And a Sass mixin should exist
      And the stdout should contain "written  Sass"

  Scenario: When nothing is generated
    Given I have a default project
      And I have 1 source in public/images/sprites/fry
      And I run "flexo generate"
    When I run "flexo generate"
    Then the stdout should not contain "written  Sass"

  Scenario: Disabling Sass in the config file
    Given I have a project with config:
    """
    ---
      config.sass false

      sprites 'public/images/sprites/:name/*' => 'public/images/:name.png'
    """
    Then a Sass mixin should not exist
