# TAEL AI mac agent — common dev commands.
#
# Most of this requires macOS + Xcode 15.3+. The repo also contains
# `TAELMacAgent/project.yml` so the .xcodeproj can be regenerated with
# XcodeGen if the committed pbxproj ever drifts.

PROJECT := TAELMacAgent/TAELMacAgent.xcodeproj
SCHEME  := TAELMacAgent
DEST    := platform=macOS

.PHONY: help
help:
	@echo "TAEL AI mac agent — make targets"
	@echo ""
	@echo "  make build           Build the app (Debug)"
	@echo "  make test            Run unit tests"
	@echo "  make run             Build and launch the app"
	@echo "  make clean           Clean build artifacts"
	@echo "  make xcodeproj       Regenerate .xcodeproj from project.yml (requires xcodegen)"
	@echo "  make package-alpha   Build, notarize, and staple internal alpha DMG"
	@echo "  make tcc-reset       Reset TCC entries for ai.tael.macagent (dev only)"
	@echo ""
	@echo "Requirements: macOS 14.0+, Xcode 15.3+. See TODO_FOR_OZZY.md."

.PHONY: build
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
	    -destination '$(DEST)' clean build

.PHONY: test
test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	    -destination '$(DEST)' test

.PHONY: run
run: build
	open "$(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings | awk -F'= ' '/ BUILT_PRODUCTS_DIR / {print $$2}' | head -n1)/TAELMacAgent.app"

.PHONY: clean
clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf TAELMacAgent/build TAELMacAgent/DerivedData

.PHONY: xcodeproj
xcodeproj:
	@command -v xcodegen >/dev/null 2>&1 || { \
	    echo "error: xcodegen is not installed. Install with 'brew install xcodegen'." >&2; \
	    exit 1; \
	}
	cd TAELMacAgent && xcodegen generate

.PHONY: package-alpha
package-alpha:
	./scripts/package-alpha-dmg.sh

.PHONY: tcc-reset
tcc-reset:
	./scripts/reset-tcc-dev.sh
