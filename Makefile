.PHONY: help check summary lint watch install clean

# Default target
help:
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Thea - Automatic Error Detection Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "📋 Available Commands:"
	@echo ""
	@echo "  make check      - Run full error scan (SwiftLint + compilation)"
	@echo "  make summary    - Show quick error statistics"
	@echo "  make lint       - Run SwiftLint only"
	@echo "  make watch      - Start continuous file monitoring"
	@echo "  make install    - Run full installation"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make help       - Show this help message"
	@echo ""
	@echo "🔧 Setup Commands:"
	@echo ""
	@echo "  make xcode      - Configure Xcode settings"
	@echo "  make hooks      - Install Git pre-commit hook"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""

# Run comprehensive error check
check:
	@./Scripts/build-with-all-errors.sh

# Show error summary
summary:
	@./Scripts/error-summary.sh

# Run SwiftLint only
lint:
	@echo "Running SwiftLint..."
	@swiftlint lint --config .swiftlint.yml

# Start file watcher
watch:
	@./Scripts/watch-and-check.sh

# Run full installation
install:
	@./install-automatic-checks.sh

# Configure Xcode settings
xcode:
	@./Scripts/configure-xcode.sh

# Install Git hooks
hooks:
	@echo "Installing Git pre-commit hook..."
	@cp Scripts/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build .build DerivedData
	@echo "✅ Build artifacts cleaned"
