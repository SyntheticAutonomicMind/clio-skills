---
name: "terminal-ui"
description: "Terminal UI design patterns for CLI applications"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations"]
---

# Terminal UI Skill

## When to Use

- Building CLI applications
- Creating interactive terminal interfaces
- Designing command output formatting

## Terminal UI Principles

### 1. Visual Hierarchy

Use consistent patterns to guide the user's eye:

```
═══════════════════════════════════════════════════════════════
MAIN HEADER
═══════════════════════════════════════════════════════════════

SECTION HEADER
──────────────────────────────────────────────────────────────
Content here with proper indentation
  • List items
  • More items

ANOTHER SECTION
──────────────────────────────────────────────────────────────
Key:             Value (aligned)
Longer Key:      Another value
```

### 2. ANSI Color Conventions

**Semantic Colors (common patterns):**
- **Green** - Success, positive actions, user input
- **Red** - Errors, destructive actions
- **Yellow** - Warnings, caution
- **Cyan** - Headers, important info
- **White** - Normal text
- **Gray/Dim** - Less important info, borders

**ANSI Escape Codes:**
```
\e[0m  - Reset all
\e[1m  - Bold
\e[2m  - Dim
\e[4m  - Underline

Foreground colors (30-37):
\e[31m - Red      \e[91m - Bright red
\e[32m - Green    \e[92m - Bright green
\e[33m - Yellow   \e[93m - Bright yellow
\e[34m - Blue     \e[94m - Bright blue
\e[35m - Magenta  \e[95m - Bright magenta
\e[36m - Cyan     \e[96m - Bright cyan
\e[37m - White    \e[97m - Bright white
```

### 3. Spacing Conventions

```
# Blank line before section headers
print "\n";
print "SECTION\n";
print "───────\n";

# Blank line after sections
print "content\n";
print "\n";

# Consistent indentation (2 spaces is common)
print "  Item 1\n";
print "  Item 2\n";
```

### 4. Progress Indicators

**Spinners (frame sequences):**
```
⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏   # Braille dots (smooth)
- \ | /                    # ASCII (basic/portable)
▏▎▍▌▋▊▉█                  # Block fill
◐ ◓ ◑ ◒                    # Circle quarters
```

**Progress Bars:**
```
[████████░░░░░░░░░░░░] 40%
[##########..........] 50%
Processing... ████████░░░░ 60%
```

### 5. Lists and Tables

**Bulleted Lists:**
```
  • Item one
  • Item two
  • Item three
```

**Numbered Lists:**
```
  1. First step
  2. Second step
  3. Third step
```

**Key-Value Alignment:**
```perl
# Perl example using printf
my $width = 20;
printf("%-${width}s %s\n", "Key:", $value);

# Python example
print(f"{'Key:':<20} {value}")
```

**Box Drawing Tables:**
```
┌──────────┬──────────┬──────────┐
│ Header 1 │ Header 2 │ Header 3 │
├──────────┼──────────┼──────────┤
│ Data     │ Data     │ Data     │
└──────────┴──────────┴──────────┘
```

### 6. User Input Prompts

**Confirmation:**
```
Delete file? [y/N]: 
Continue? (yes/no): 
Overwrite existing? [Y/n]: 

# [Y/n] means Y is default (press Enter)
# [y/N] means N is default
```

**Selection:**
```
Select an option:
  [1] First choice
  [2] Second choice
  [3] Third choice
> 
```

### 7. Error Messages

**Format:** Clear, specific, actionable

```
ERROR: Cannot open file: /path/to/file.txt
       File does not exist.
       
       Suggestion: Check the path and try again.
```

**Not:** `Error: ENOENT` (cryptic, unhelpful)

### 8. Responsive Design

```perl
# Get terminal width
my $width = `tput cols` || 80;
chomp($width);

# Or from environment
my $width = $ENV{COLUMNS} || 80;

# Truncate long content
my $max = $width - 10;
if (length($text) > $max) {
    $text = substr($text, 0, $max - 3) . "...";
}
```

### 9. Keyboard Handling (Perl Example)

```perl
use Term::ReadKey;

# Raw mode for single keypress
ReadMode('cbreak');
my $key = ReadKey(0);  # Blocking read
ReadMode('normal');    # Always restore!

# Handle arrow keys (escape sequences)
if ($key eq "\e") {
    my $seq = ReadKey(0) . ReadKey(0);
    if ($seq eq '[A') {
        # Up arrow
    } elsif ($seq eq '[B') {
        # Down arrow
    } elsif ($seq eq '[C') {
        # Right arrow
    } elsif ($seq eq '[D') {
        # Left arrow
    }
}
```

### 10. Screen Control Sequences

```bash
# Clear screen and move to top
printf '\e[2J\e[H'

# Clear current line
printf '\e[2K\r'

# Move cursor to row,col
printf '\e[%d;%dH' $row $col

# Save/restore cursor position
printf '\e[s'   # Save
printf '\e[u'   # Restore

# Alternate screen buffer (for full-screen UIs)
printf '\e[?1049h'  # Enter (hides scrollback)
printf '\e[?1049l'  # Leave (restores scrollback)
```

### 11. Best Practices

1. **Always restore terminal state** - If you change modes, reset before exit
2. **Support piped output** - Detect `-t STDOUT` and disable colors/interactivity
3. **Handle SIGINT/SIGTERM** - Clean up properly on interrupt
4. **Respect NO_COLOR environment** - `if defined $ENV{NO_COLOR}`
5. **Test on multiple terminals** - xterm, iTerm, Windows Terminal, etc.
6. **Provide fallback for missing Unicode** - ASCII alternatives
