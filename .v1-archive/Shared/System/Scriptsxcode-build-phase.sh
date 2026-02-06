# Xcode Run Script Phase - Add Error Detection
# Add this as a "Run Script Phase" in your Xcode target's Build Phases
#
# To add:
# 1. Open your Xcode project
# 2. Select your target
# 3. Go to "Build Phases"
# 4. Click "+" and add "New Run Script Phase"
# 5. Paste the content below

# ----- SwiftLint Integration -----
# Uncomment if you have SwiftLint installed (brew install swiftlint)

# if which swiftlint >/dev/null; then
#   swiftlint
# else
#   echo "warning: SwiftLint not installed. Install with: brew install swiftlint"
# fi

# ----- Additional Compiler Flags -----
# These flags help catch more errors during compilation

# Enable stricter type checking
export OTHER_SWIFT_FLAGS="-warn-concurrency -enable-actor-data-race-checks -warnings-as-errors"

# Show all warnings
export GCC_WARN_ABOUT_DEPRECATED_FUNCTIONS="YES"
export CLANG_WARN_DOCUMENTATION_COMMENTS="YES"
export CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER="YES"

# Enable index-while-building for faster error detection
export COMPILER_INDEX_STORE_ENABLE="YES"

echo "✅ Enhanced error detection enabled"
