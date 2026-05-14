# frozen_string_literal: true

# These scenarios document the system contract between GitHub (canonical source)
# and Forgejo (pull mirror). They are documentation scenarios — the sync itself
# is managed server-side by Forgejo's pull-mirror mechanism, not by application code.

@documentation
Feature: GitHub is the single source of truth; Forgejo mirrors it automatically

  Background:
    Given GitHub hosts the canonical rake-gem-maintenance repository
    And Forgejo is configured as a pull mirror of the GitHub repository
    And Woodpecker CI watches the Forgejo mirror

  # --- PR workflow ---

  Scenario: All pull requests are opened on GitHub
    When a developer wants to propose a change
    Then they open a pull request on GitHub
    And no corresponding pull request exists on Forgejo

  Scenario: Merged GitHub PR appears on Forgejo after the mirror syncs
    Given a pull request has been merged to main on GitHub
    When the Forgejo mirror sync runs
    Then the merge commit is present on Forgejo main

  # --- Branch / tag propagation ---

  Scenario: Tags pushed to GitHub are mirrored to Forgejo
    Given a version tag is pushed to GitHub
    When the Forgejo mirror sync runs
    Then the tag exists in the Forgejo repository

  Scenario: Feature branches on GitHub are not tracked by Woodpecker
    Given a feature branch exists on GitHub
    When the Forgejo mirror sync propagates it
    Then Woodpecker does not run a pipeline for that feature branch

  # --- WP CI triggers ---

  Scenario: Woodpecker verify pipeline runs when Forgejo main is updated
    Given the Forgejo mirror has received new commits on main
    Then Woodpecker triggers the verify pipeline

  Scenario: Woodpecker publish pipeline runs when main is synced after a release
    Given a release commit and its tag have been pushed to GitHub main
    And the Forgejo mirror has synced them
    Then Woodpecker triggers the publish pipeline exactly once

  # --- Divergence guard ---

  Scenario: Force-push to GitHub main propagates without conflict
    Given GitHub main has been rebased and force-pushed
    When the Forgejo mirror sync runs with force-sync enabled
    Then Forgejo main matches GitHub main exactly
