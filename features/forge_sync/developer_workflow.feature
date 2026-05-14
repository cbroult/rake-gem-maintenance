# frozen_string_literal: true

# These scenarios document the expected developer workflow now that
# Forgejo is a server-side pull mirror. Developers interact only with
# the GitHub remote; Forgejo syncs automatically.

@documentation
Feature: Developer workflow with a single PR platform

  Scenario: Developer does not need to push to Forgejo manually
    Given the Forgejo pull mirror is active
    When a developer pushes commits to GitHub
    Then Forgejo receives those commits automatically within the mirror interval
    And the developer does not need to run "git push forgejo"

  Scenario: Developer clones the repository with only the GitHub remote
    Given the Forgejo mirror is configured server-side
    When a developer clones the repository from GitHub
    Then only the "origin" remote pointing to GitHub is configured
    And no "forgejo" remote exists

  Scenario: Developer removes a stale forgejo remote from an existing clone
    Given a developer's local clone has a "forgejo" remote from a previous setup
    When they run "git remote remove forgejo"
    Then the local clone has only the "origin" remote
    And pushes go only to GitHub

  Scenario: Badge on Woodpecker reflects the latest GitHub commit
    Given the Forgejo mirror is up to date with GitHub main
    And the Woodpecker verify pipeline has completed
    Then the build badge reflects the result of the latest GitHub commit
