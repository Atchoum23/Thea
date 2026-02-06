# Makefile for Thea Project Error Detection
# Usage: make <target>

.PHONY: help setup configure check summary watch clean install

help: ## Show this help message
	@echo "📚 Thea Error Detection Tools"
	@echo "📁 Project: /Users/alexis/Documents/IT & Tech/MyApps/Thea"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make setup      # One-time setup (run this first!)"
	@echo "  make check      # Check all errors"
	@echo "  make summary    # Quick error summary"
	@echo "  make watch      # Watch for changes"

setup: ## One-time setup - run this first!
	@chmod +x setup.sh
	@./setup.sh

setup-auto: ## Setup with AUTOMATIC execution on every build
	@chmod +x install-automatic-checks.sh
	@./install-automatic-checks.sh

configure: ## Configure Xcode for optimal error detection (run once)
	@chmod +x Scripts/configure-xcode.sh
	@./Scripts/configure-xcode.sh

check: ## Check all Swift files for errors
	@chmod +x Scripts/build-with-all-errors.sh
	@./Scripts/build-with-all-errors.sh

summary: ## Show quick error summary
	@chmod +x Scripts/error-summary.sh
	@./Scripts/error-summary.sh

watch: ## Watch files and continuously type-check
	@chmod +x Scripts/watch-and-check.sh
	@./Scripts/watch-and-check.sh

clean: ## Clean build artifacts and error reports
	@echo "🧹 Cleaning..."
	@rm -f build-errors-*.txt
	@echo "✅ Cleaned error reports"

install: ## Install required tools (SwiftLint, fswatch)
	@echo "📦 Installing tools..."
	@command -v brew >/dev/null 2>&1 || { echo "❌ Homebrew required. Install from https://brew.sh"; exit 1; }
	@echo "Installing SwiftLint..."
	@brew install swiftlint 2>/dev/null || echo "SwiftLint already installed"
	@echo "Installing fswatch..."
	@brew install fswatch 2>/dev/null || echo "fswatch already installed"
	@echo "✅ Tools installed"

lint: ## Run SwiftLint
	@command -v swiftlint >/dev/null 2>&1 || { echo "❌ SwiftLint not installed. Run: make install"; exit 1; }
	@swiftlint

fix-lint: ## Auto-fix SwiftLint issues
	@command -v swiftlint >/dev/null 2>&1 || { echo "❌ SwiftLint not installed. Run: make install"; exit 1; }
	@swiftlint --fix

build: ## Standard build
	@xcodebuild -scheme Thea build

test: ## Run tests
	@xcodebuild -scheme Thea test

setup-git-hooks: ## Install Git pre-commit hook
	@echo "🪝 Installing Git hooks..."
	@chmod +x Scripts/pre-commit
	@cp Scripts/pre-commit .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed"

all: configure install setup-git-hooks check ## Setup everything and check for errors
	@echo "✅ All done!"
