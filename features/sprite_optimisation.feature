@polymer-bond @polymer-optimise
Feature: Optimising sprites after generation

  In order to reduce the payload sent to users of application
  I want to be able to reduce images to their smallest possible size

  Scenario: Optimising when generating new sprites
    Given I have a default project
      And I have 1 source in sources/fry
    When I run "polymer bond"
    Then the exit status should be 0
      And the "fry" sprite should have been optimised

  Scenario: Optimising only changed sprites
    Given I have a default project
      And I have 1 source in sources/fry
      And I have 1 source in sources/leela
      And I run "polymer bond"
      And I have a "one" source at sources/fry which is 100x25
    When I run "polymer bond"
    Then the exit status should be 0
      And the "fry" sprite should have been optimised
      And the "leela" sprite should not have been optimised

  Scenario: Optimising generated sprites with --force
    Given I have a default project
      And I have 1 source in sources/fry
      And I run "polymer bond"
    When I run "polymer bond --force"
    Then the "fry" sprite should have been optimised

  Scenario: Skipping optimisation of generated sprites with --fast
    Given I have a default project
      And I have 1 source in sources/fry
      And I run "polymer bond"
    When I run "polymer bond --fast"
    Then the "fry" sprite should not have been optimised