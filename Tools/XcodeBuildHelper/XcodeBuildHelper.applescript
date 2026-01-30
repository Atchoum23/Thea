-- XcodeBuildHelper.applescript
-- Standalone AppleScript application for Xcode GUI automation
-- This app can be granted Accessibility permissions independently
-- Usage: Run with scheme name as argument, e.g.: open -a XcodeBuildHelper.app --args Thea-iOS

on run argv
    -- Get scheme from arguments or use default
    if (count of argv) > 0 then
        set schemeName to item 1 of argv
    else
        set schemeName to "Thea-macOS"
    end if

    -- Get configuration from second argument (default: Debug)
    if (count of argv) > 1 then
        set configName to item 2 of argv
    else
        set configName to "Debug"
    end if

    -- Build the scheme
    my buildScheme(schemeName)

    return "Build started for " & schemeName
end run

on buildScheme(schemeName)
    tell application "Xcode"
        activate
    end tell

    delay 1

    tell application "System Events"
        tell process "Xcode"
            -- Wait for Xcode to be ready
            repeat 10 times
                if exists window 1 then exit repeat
                delay 0.5
            end repeat

            -- Open scheme chooser (Ctrl+0)
            keystroke "0" using {control down}
            delay 0.5

            -- Clear any existing text and type scheme name
            keystroke "a" using {command down}
            delay 0.1
            keystroke schemeName
            delay 0.3

            -- Select the scheme
            keystroke return
            delay 0.5

            -- Clean build folder first (Cmd+Shift+K)
            -- keystroke "k" using {command down, shift down}
            -- delay 1

            -- Build (Cmd+B)
            keystroke "b" using {command down}
        end tell
    end tell
end buildScheme
