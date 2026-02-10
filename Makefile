.PHONY: help generate build build-ios build-watchos build-tvos build-all \
       build-release test test-spm test-asan test-tsan lint audit \
       clean clean-derived check summary watch install xcode hooks qa

# Default target
help:
	@echo ""
	@echo "  Thea Build System"
	@echo "  ================="
	@echo ""
	@echo "  Build:"
	@echo "    make generate       - Regenerate Xcode project from project.yml"
	@echo "    make build          - Build macOS (Debug)"
	@echo "    make build-ios      - Build iOS (Debug)"
	@echo "    make build-watchos  - Build watchOS (Debug)"
	@echo "    make build-tvos     - Build tvOS (Debug)"
	@echo "    make build-all      - Build all 4 platforms (Debug)"
	@echo "    make build-release  - Build macOS (Release)"
	@echo ""
	@echo "  Test:"
	@echo "    make test           - Run SPM tests (fast, ~1s)"
	@echo "    make test-spm       - Alias for test"
	@echo "    make test-asan      - Run tests with Address Sanitizer"
	@echo "    make test-tsan      - Run tests with Thread Sanitizer"
	@echo ""
	@echo "  Quality:"
	@echo "    make lint           - Run SwiftLint"
	@echo "    make audit          - Build and run thea-audit security scanner"
	@echo "    make qa             - Full QA: lint + test + build-all"
	@echo "    make check          - Run build error scan script"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make clean          - Clean local .build directory"
	@echo "    make clean-derived  - Clean Thea DerivedData"
	@echo "    make hooks          - Install Git pre-commit hook"
	@echo ""

# Regenerate Xcode project
generate:
	@echo "Regenerating Xcode project..."
	@xcodegen generate
	@echo "Done."

# Build macOS Debug
build: generate
	xcodebuild build \
		-project Thea.xcodeproj \
		-scheme Thea-macOS \
		-destination 'platform=macOS' \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Build iOS Debug
build-ios: generate
	xcodebuild build \
		-project Thea.xcodeproj \
		-scheme Thea-iOS \
		-destination 'generic/platform=iOS' \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Build watchOS Debug
build-watchos: generate
	xcodebuild build \
		-project Thea.xcodeproj \
		-scheme Thea-watchOS \
		-destination 'generic/platform=watchOS' \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Build tvOS Debug
build-tvos: generate
	xcodebuild build \
		-project Thea.xcodeproj \
		-scheme Thea-tvOS \
		-destination 'generic/platform=tvOS' \
		-configuration Debug \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Build all platforms (sequentially to avoid database locks)
build-all: generate
	@echo "Building macOS..."
	@$(MAKE) build
	@echo "Building iOS..."
	@$(MAKE) build-ios
	@echo "Building watchOS..."
	@$(MAKE) build-watchos
	@echo "Building tvOS..."
	@$(MAKE) build-tvos
	@echo "All 4 platforms built successfully."

# Build macOS Release
build-release: generate
	xcodebuild build \
		-project Thea.xcodeproj \
		-scheme Thea-macOS \
		-destination 'platform=macOS' \
		-configuration Release \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

# Run SPM tests (fast)
test:
	swift test

test-spm: test

# Run tests with Address Sanitizer
test-asan:
	swift test --sanitize=address

# Run tests with Thread Sanitizer
test-tsan:
	swift test --sanitize=thread

# Run SwiftLint
lint:
	@swiftlint lint --config .swiftlint.yml

# Build and run thea-audit security scanner
audit:
	@echo "Building thea-audit..."
	@cd Tools/thea-audit && xcrun swift build -c release
	@echo "Running security audit..."
	@Tools/thea-audit/.build/release/thea-audit scan \
		--path . \
		--format markdown \
		--output audit-report.md \
		--severity low \
		--policy thea-policy.json || true
	@echo "Audit report: audit-report.md"

# Full QA pipeline
qa: lint test build-all
	@echo "QA passed: lint + test + all platforms."

# Run build error scan script
check:
	@if [ -f Scripts/build-with-all-errors.sh ]; then \
		./Scripts/build-with-all-errors.sh; \
	else \
		echo "Scripts/build-with-all-errors.sh not found. Use 'make build' instead."; \
	fi

# Show error summary
summary:
	@if [ -f Scripts/error-summary.sh ]; then \
		./Scripts/error-summary.sh; \
	else \
		echo "Scripts/error-summary.sh not found."; \
	fi

# Start file watcher
watch:
	@if [ -f Scripts/watch-and-check.sh ]; then \
		./Scripts/watch-and-check.sh; \
	else \
		echo "Scripts/watch-and-check.sh not found."; \
	fi

# Install Git hooks
hooks:
	@echo "Installing Git pre-commit hook..."
	@if [ -f Scripts/pre-commit ]; then \
		cp Scripts/pre-commit .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "Pre-commit hook installed."; \
	else \
		echo "Scripts/pre-commit not found."; \
	fi

# Clean local build artifacts
clean:
	@echo "Cleaning .build directory..."
	@rm -rf .build
	@echo "Done."

# Clean Thea DerivedData (safe pattern)
clean-derived:
	@echo "Cleaning Thea DerivedData..."
	@find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Done."
