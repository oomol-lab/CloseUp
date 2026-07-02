SCHEME      := CloseUp
CONFIG      ?= Debug
# We ship one app per architecture (no universal binaries — download size).
# `make build ARCH=x86_64` cross-builds the Intel app (via the generic
# destination — `arch=x86_64` is not a valid destination on Apple Silicon);
# the result runs locally under Rosetta. Tests always run on the host arch.
ARCH        ?= arm64
DERIVED     := build/DerivedData
ifeq ($(CONFIG),Debug)
APP_NAME    := CloseUp Dev
else
APP_NAME    := CloseUp
endif
# arm64 uses a concrete destination so ONLY_ACTIVE_ARCH can pin the host slice;
# any other arch cross-builds via the generic destination with ARCHS forced.
# The shipped per-arch app is single-slice (a post-build phase thins Sparkle).
ifeq ($(ARCH),arm64)
DEST        := platform=macOS,arch=arm64
ARCHFLAGS   := ARCHS=arm64
else
DEST        := generic/platform=macOS
ARCHFLAGS   := ARCHS=$(ARCH) ONLY_ACTIVE_ARCH=NO
endif
APP         := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app
DMG         := build/dmg/CloseUp.dmg
XCB         := set -o pipefail && xcodebuild
PRETTY      := | xcbeautify

# Opt-in stable Debug signing identity (see `make dev-cert` / scripts/make-dev-cert.sh):
# if it exists in the keychain, sign the Debug build with it so the Accessibility
# TCC grant survives rebuilds; otherwise leave the project's ad-hoc ("-") signing
# so a fresh clone builds with zero setup. Release (Developer ID) is unaffected.
DEV_SIGN_ID := CloseUp Dev Self-Signed
ifeq ($(CONFIG),Debug)
# NB: no `-v` — the cert is a self-signed (untrusted) root, which `find-identity -v`
# filters out, but codesign signs with it fine and that is all we need.
ifneq ($(shell security find-identity -p codesigning 2>/dev/null | grep -c "$(DEV_SIGN_ID)"),0)
# Force Manual style alongside the identity: the override is global (it reaches the
# SPM dependency targets too), and a named identity under Automatic signing demands
# a development team — Manual + explicit identity does not.
SIGN        := CODE_SIGN_IDENTITY="$(DEV_SIGN_ID)" CODE_SIGN_STYLE=Manual
endif
endif

.PHONY: gen build run test archive dmg clean kill dev-cert \
	update-test-none update-test-download-fail update-test-extract-fail \
	update-test-success update-test-stop

## Regenerate the Xcode project from project.yml
gen:
	xcodegen generate

## Create a stable local self-signed identity for the Debug build so the
## Accessibility grant survives rebuilds (opt-in; writes to YOUR login keychain).
## Safe to re-run. See scripts/make-dev-cert.sh.
dev-cert:
	@scripts/make-dev-cert.sh

## Build the app (Debug by default; CONFIG=Release for the shipping config;
## ARCH=x86_64 for the Intel app)
build: gen
	$(XCB) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -destination '$(DEST)' \
		$(SIGN) $(ARCHFLAGS) build $(PRETTY)

## Build and launch the app
run: build
	@pkill -x "$(APP_NAME)" 2>/dev/null || true
	@i=0; while pgrep -x "$(APP_NAME)" >/dev/null && [ $$i -lt 50 ]; do sleep 0.1; i=$$((i+1)); done
	open "$(APP)"

## Run the unit tests (hardware-touching suites skipped)
test: gen
	$(XCB) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS' test $(PRETTY)

## Build a Release archive (Developer ID; ARCH=x86_64 for the Intel archive)
archive: gen
	$(XCB) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(DERIVED) -destination 'generic/platform=macOS' \
		-archivePath build/CloseUp-$(ARCH).xcarchive \
		$(ARCHFLAGS) archive $(PRETTY)

## Package the built app into a drag-to-install .dmg (CONFIG=Release for a
## release-config bundle; the image is unsigned/unnotarized — CI handles that)
dmg: build
	scripts/make-dmg.sh "$(APP)" "$(DMG)"

## Terminate a running instance
kill:
	@pkill -x "$(APP_NAME)" 2>/dev/null || true

# ——— Update lab: exercise the Sparkle update flows against a local feed ———
# (see scripts/update-lab/; each scenario rebuilds, relaunches, and prints
# what to expect. `make update-test-stop` tears everything down.)
UPDATE_LAB := scripts/update-lab/update-lab.sh

## Update lab: "You're up to date." (feed advertises the running version)
update-test-none: build
	@UPDATE_LAB_APP="$(APP)" $(UPDATE_LAB) none

## Update lab: download dies mid-transfer → download-failed error
update-test-download-fail: build
	@UPDATE_LAB_APP="$(APP)" $(UPDATE_LAB) download-fail

## Update lab: archive is signed but corrupt → extraction fails
update-test-extract-fail: build
	@UPDATE_LAB_APP="$(APP)" $(UPDATE_LAB) extract-fail

## Update lab: real end-to-end update — download, install, relaunch
update-test-success: build
	@UPDATE_LAB_APP="$(APP)" $(UPDATE_LAB) success

## Update lab: stop the feed server and the app under test
update-test-stop:
	@$(UPDATE_LAB) stop

## Remove generated project and build artifacts
clean:
	rm -rf build CloseUp.xcodeproj
