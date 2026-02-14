#!/bin/bash
# Configure Xcode for better error detection
# Run this once to apply optimal settings

echo "🔧 Configuring Xcode for maximum error detection..."

# Enable live issues (show errors as you type)
defaults write com.apple.dt.Xcode ShowLiveIssues -bool YES

# Show issues navigator on build failure
defaults write com.apple.dt.Xcode IDEBuildOnFailureOpenIssueNavigator -bool YES

# Enable parallel compilation
defaults write com.apple.dt.Xcode BuildSystemScheduleInherentlyParallelCommandsExclusively -bool NO

# Set maximum concurrent compile tasks (adjust based on your CPU cores)
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks 8

# Show all build steps
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES

# Enable index-while-building (faster error detection)
defaults write com.apple.dt.Xcode IDEIndexEnableDataStore -bool YES

# Show build times
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES

# Enable additional warnings
defaults write com.apple.dt.Xcode Xcode.IDEFoundation.Build.ShowAllIssues -bool YES

# Restart Xcode warning
echo ""
echo "✅ Xcode settings configured!"
echo ""
echo "⚠️  Please restart Xcode for changes to take effect."
echo ""
echo "Settings applied:"
echo "  • Live issues enabled (errors shown as you type)"
echo "  • Parallel compilation enabled"
echo "  • Issue navigator opens on build failure"
echo "  • Maximum concurrent tasks: 8"
echo "  • Index-while-building enabled"
echo ""
