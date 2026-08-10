class_name BuildConfig
extends RefCounted
## Centralized release configuration for Beta 0.1 (internal TestFlight).
##
## This is the single source of truth for build/environment identity and for
## gating every debug/developer/cheat surface in the app. Nothing else in the
## codebase should call `OS.is_debug_build()` directly for gating user-facing
## behavior — route it through this file so release safety rules live in one
## place and can be audited/changed without hunting through every screen.

## Public-facing beta version shown to testers (independent of the internal
## engineering `config/version` in project.godot).
const APP_VERSION := "0.1.0-beta.2"
## Bump for every new store / device build upload (Android versionCode).
const BUILD_NUMBER := 2
## "development" | "beta" | "production" — informational; gating itself is
## always driven by `is_debug_build()` so a mis-set environment string can
## never accidentally leave cheats reachable in a release export.
const ENVIRONMENT := "beta"

## Authoritative Android applicationId / package unique name (export_presets.cfg).
const ANDROID_PACKAGE_ID := "com.sugarstreettycoon.game"
## Player-facing Android launcher label (package/name). Not the marketing subtitle.
const ANDROID_APP_NAME := "Sugar Street Tycoon"

## Save-file identity. A named slot leaves room for multiple profiles later
## without another migration.
const SAVE_SLOT_NAME := "default"
## Saves older than this version are considered unsupported and fall back to
## defaults instead of attempting a migration that could produce bad data.
const MINIMUM_SUPPORTED_SAVE_VERSION := 1


## True only for actual Godot editor / debug-export runs. This is FALSE in a
## release (TestFlight/App Store) export — the only reliable release/debug
## signal Godot provides — so every gate below inherits that safety property.
static func is_debug_build() -> bool:
	return OS.is_debug_build()


## Debug-only systems: extra board/shop debug panels, keyboard debug actions,
## the Beta Diagnostics screen, one-button smoke test, etc.
static func debug_features_enabled() -> bool:
	return is_debug_build()


## The in-shop "Developer Menu" / debug tools panel (coin grants, unlock-all,
## force states). Must never be reachable in a beta release build.
static func developer_menu_enabled() -> bool:
	return is_debug_build()


## Extra `print()`/diagnostic logging. Kept off in release to reduce noise
## and avoid leaking internal state to device consoles.
static func verbose_logging_enabled() -> bool:
	return is_debug_build()


## No real IAP exists yet. Mock purchases (if ever added for testing a store
## flow) must only ever be reachable in debug builds, never in a beta/TestFlight
## build a real tester could confuse for a real transaction.
static func mock_purchases_enabled() -> bool:
	return is_debug_build()


## Beta 0.1 intentionally ships with placeholder art; gameplay/UI must read
## this flag instead of hardcoding asset assumptions so final art can drop in
## later without another gating pass.
static func use_placeholder_assets() -> bool:
	return true


## Destructive actions (New Game reset, Reset Inventory, clear save, etc.)
## must always confirm — in every build, not just release — so this is not
## gated by debug/beta at all. Kept as an explicit named rule so callers don't
## have to guess.
static func requires_confirmation_for_destructive_actions() -> bool:
	return true


## Internal file paths (res://, user://, absolute OS paths) must never be
## shown in release UI (e.g. error toasts). Debug screens may show them.
static func internal_paths_may_be_shown() -> bool:
	return is_debug_build()


static func version_label() -> String:
	return "%s (%d)" % [APP_VERSION, BUILD_NUMBER]


static func environment_label() -> String:
	return ENVIRONMENT.capitalize()
