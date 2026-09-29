enum GhosttyScripts {
  static let ensureWindow = #"""
    tell application "Ghostty"
        if (count of windows) is 0 then
            set createdWindow to new window
            return id of createdWindow
        end if
        return id of front window
    end tell
    """#

  static let list = #"""
    on replaceText(needle, replacement, sourceText)
        set previousDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to needle
        set sourceItems to every text item of sourceText
        set AppleScript's text item delimiters to replacement
        set resultText to sourceItems as text
        set AppleScript's text item delimiters to previousDelimiters
        return resultText
    end replaceText

    on encodeField(value)
        set resultText to value as text
        set resultText to my replaceText("\\", "\\\\", resultText)
        set resultText to my replaceText(tab, "\\t", resultText)
        set resultText to my replaceText(linefeed, "\\n", resultText)
        set resultText to my replaceText(ASCII character 13, "\\r", resultText)
        return resultText
    end encodeField

    on joinFields(fields)
        set previousDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to tab
        set resultText to fields as text
        set AppleScript's text item delimiters to previousDelimiters
        return resultText
    end joinFields

    on joinLines(lineValues)
        set previousDelimiters to AppleScript's text item delimiters
        set AppleScript's text item delimiters to linefeed
        set resultText to lineValues as text
        set AppleScript's text item delimiters to previousDelimiters
        return resultText
    end joinLines

    set resultLines to {}
    tell application "Ghostty"
        repeat with windowRef in windows
            set windowID to (id of windowRef) as text
            set windowName to (name of windowRef) as text
            repeat with tabRef in tabs of windowRef
                set tabID to (id of tabRef) as text
                set tabName to (name of tabRef) as text
                set tabIndex to (index of tabRef) as text
                set tabSelected to (selected of tabRef) as text
                set focusedID to (id of focused terminal of tabRef) as text
                repeat with terminalRef in terminals of tabRef
                    set terminalID to (id of terminalRef) as text
                    set fields to {my encodeField(windowID), my encodeField(windowName), my encodeField(tabID), my encodeField(tabName), tabIndex, tabSelected, my encodeField(terminalID), my encodeField(name of terminalRef), my encodeField(working directory of terminalRef), (pid of terminalRef) as text, my encodeField(tty of terminalRef), (terminalID is focusedID) as text}
                    set end of resultLines to my joinFields(fields)
                end repeat
            end repeat
        end repeat
    end tell
    return my joinLines(resultLines)
    """#

  static let type = #"""
    on run argv
        set terminalID to item 1 of argv
        set payload to item 2 of argv
        set shouldPressEnter to item 3 of argv is "true"
        tell application "Ghostty"
            if terminalID is "" then
                set targetTerminal to focused terminal of selected tab of front window
            else
                set targetTerminal to first terminal whose id is terminalID
            end if
            input text payload to targetTerminal
            if shouldPressEnter then
                send key "enter" to targetTerminal
            end if
            return id of targetTerminal
        end tell
    end run
    """#

  static let newTab = #"""
    on run argv
        set windowID to item 1 of argv
        set workingDirectory to item 2 of argv
        tell application "Ghostty"
            if windowID is "" then
                set targetWindow to front window
            else
                set targetWindow to first window whose id is windowID
            end if

            if workingDirectory is "" then
                set createdTab to new tab in targetWindow
            else
                set surfaceConfiguration to new surface configuration
                set initial working directory of surfaceConfiguration to workingDirectory
                set createdTab to new tab in targetWindow with configuration surfaceConfiguration
            end if
            return id of focused terminal of createdTab
        end tell
    end run
    """#

  static let newWindow = #"""
    on run argv
        set workingDirectory to item 1 of argv
        set fieldSeparator to ASCII character 9
        tell application "Ghostty"
            if workingDirectory is "" then
                set createdWindow to new window
            else
                set surfaceConfiguration to new surface configuration
                set initial working directory of surfaceConfiguration to workingDirectory
                set createdWindow to new window with configuration surfaceConfiguration
            end if
            set createdTab to selected tab of createdWindow
            set createdTerminal to focused terminal of createdTab
            return (id of createdWindow) & fieldSeparator & (id of createdTab) & fieldSeparator & (id of createdTerminal)
        end tell
    end run
    """#

  static let split = #"""
    on run argv
        set terminalID to item 1 of argv
        set directionText to item 2 of argv
        set workingDirectory to item 3 of argv
        tell application "Ghostty"
            if terminalID is "" then
                set targetTerminal to focused terminal of selected tab of front window
            else
                set targetTerminal to first terminal whose id is terminalID
            end if

            if workingDirectory is not "" then
                set surfaceConfiguration to new surface configuration
                set initial working directory of surfaceConfiguration to workingDirectory
            end if

            if directionText is "right" then
                if workingDirectory is "" then
                    set createdTerminal to split targetTerminal direction right
                else
                    set createdTerminal to split targetTerminal direction right with configuration surfaceConfiguration
                end if
            else if directionText is "left" then
                if workingDirectory is "" then
                    set createdTerminal to split targetTerminal direction left
                else
                    set createdTerminal to split targetTerminal direction left with configuration surfaceConfiguration
                end if
            else if directionText is "down" then
                if workingDirectory is "" then
                    set createdTerminal to split targetTerminal direction down
                else
                    set createdTerminal to split targetTerminal direction down with configuration surfaceConfiguration
                end if
            else
                if workingDirectory is "" then
                    set createdTerminal to split targetTerminal direction up
                else
                    set createdTerminal to split targetTerminal direction up with configuration surfaceConfiguration
                end if
            end if
            return id of createdTerminal
        end tell
    end run
    """#

  static let focus = #"""
    on run argv
        set terminalID to item 1 of argv
        tell application "Ghostty"
            set targetTerminal to first terminal whose id is terminalID
            focus targetTerminal
            return id of targetTerminal
        end tell
    end run
    """#

  static let close = #"""
    on run argv
        set terminalID to item 1 of argv
        tell application "Ghostty"
            set targetTerminal to first terminal whose id is terminalID
            set targetID to id of targetTerminal
            close targetTerminal
            return targetID
        end tell
    end run
    """#

  static let closeTab = #"""
    on run argv
        set tabID to item 1 of argv
        tell application "Ghostty"
            set targetTab to missing value
            repeat with windowRef in windows
                try
                    set targetTab to first tab of windowRef whose id is tabID
                    exit repeat
                end try
            end repeat
            if targetTab is missing value then error "No tab found with ID " & tabID
            set targetID to id of targetTab
            close tab targetTab
            return targetID
        end tell
    end run
    """#

  static let closeWindow = #"""
    on run argv
        set windowID to item 1 of argv
        tell application "Ghostty"
            set targetWindow to first window whose id is windowID
            set targetID to id of targetWindow
            close window targetWindow
            return targetID
        end tell
    end run
    """#

  static let performAction = #"""
    on run argv
        set terminalID to item 1 of argv
        set actionText to item 2 of argv
        set fieldSeparator to ASCII character 9
        tell application "Ghostty"
            if terminalID is "" then
                set targetTerminal to focused terminal of selected tab of front window
            else
                set targetTerminal to first terminal whose id is terminalID
            end if
            set targetID to id of targetTerminal
            set wasPerformed to perform action actionText on targetTerminal
            return targetID & fieldSeparator & (wasPerformed as text)
        end tell
    end run
    """#

  static let setTabTitle = #"""
    on run argv
        set tabID to item 1 of argv
        set titleText to item 2 of argv
        set fieldSeparator to ASCII character 9
        tell application "Ghostty"
            if tabID is "" then
                set targetTab to selected tab of front window
            else
                set targetTab to missing value
                repeat with windowRef in windows
                    try
                        set targetTab to first tab of windowRef whose id is tabID
                        exit repeat
                    end try
                end repeat
                if targetTab is missing value then error "No tab found with ID " & tabID
            end if
            set targetTerminal to focused terminal of targetTab
            set targetID to id of targetTerminal
            set wasPerformed to perform action ("set_tab_title:" & titleText) on targetTerminal
            return targetID & fieldSeparator & (wasPerformed as text)
        end tell
    end run
    """#

  static let moveTab = #"""
    on run argv
        set tabID to item 1 of argv
        set offsetText to item 2 of argv
        set fieldSeparator to ASCII character 9
        tell application "Ghostty"
            set targetTab to missing value
            set targetWindow to missing value
            repeat with windowRef in windows
                try
                    set targetTab to first tab of windowRef whose id is tabID
                    set targetWindow to windowRef
                    exit repeat
                end try
            end repeat
            if targetTab is missing value then error "No tab found with ID " & tabID

            set originalTab to selected tab of targetWindow
            set shouldRestoreSelection to id of originalTab is not tabID
            if shouldRestoreSelection then select tab targetTab

            try
                set targetTerminal to focused terminal of targetTab
                set targetID to id of targetTerminal
                set wasPerformed to perform action ("move_tab:" & offsetText) on targetTerminal
            on error errorMessage number errorNumber
                if shouldRestoreSelection then select tab originalTab
                error errorMessage number errorNumber
            end try

            if shouldRestoreSelection then select tab originalTab
            return targetID & fieldSeparator & (wasPerformed as text)
        end tell
    end run
    """#
}
