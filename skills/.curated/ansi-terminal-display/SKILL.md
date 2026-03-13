---
name: "ansi-terminal-display"
description: "Universal language-agnostic reference for terminal/TTY display: ANSI escape codes, box drawing (CP437/Unicode), visual alignment, wide chars, encoding pipeline, layout patterns, and common mistakes. Applies to all languages."
version: "1.0.0"
author: "Fewtarius"
tools: ["file_operations"]
---

# ANSI / Terminal Display - Universal Concepts

Language-agnostic reference for terminal/TTY display: escape codes, box drawing,
visual alignment, CP437 vs Unicode, and multi-column layout. Applies to C, Python,
Go, Rust, JavaScript (Node), Swift, Perl, Ruby, and any language writing to a TTY.

For PhotonBBS / Perl-specific implementation of these concepts, see the
`bbs-terminal-display` skill.

---

## TABLE OF CONTENTS

1. [The Two Terminal Worlds](#1-the-two-terminal-worlds)
2. [ANSI Escape Sequences - Complete Reference](#2-ansi-escape-sequences---complete-reference)
3. [Box Drawing Characters](#3-box-drawing-characters)
4. [CP437 Special Characters](#4-cp437-special-characters)
5. [Visual Alignment - The ANSI Width Problem](#5-visual-alignment---the-ansi-width-problem)
6. [Wide Characters (CJK, Emoji)](#6-wide-characters-cjk-emoji)
7. [Byte Encoding and Terminal I/O](#7-byte-encoding-and-terminal-io)
8. [Terminal Size and Budget](#8-terminal-size-and-budget)
9. [Text Layout Patterns](#9-text-layout-patterns)
10. [Action Log Pattern (multiplayer / real-time)](#10-action-log-pattern)
11. [ANSI Detection and Capability Negotiation](#11-ansi-detection-and-capability-negotiation)
12. [Common Mistakes](#12-common-mistakes)
13. [Color Convention Table](#13-color-convention-table)
14. [Pre-Implementation Checklist](#14-pre-implementation-checklist)

---

## 1. THE TWO TERMINAL WORLDS

Every terminal display decision depends on which client is connecting.

### 1a. The three client types

| Client type | Encoding | Box chars | Color | Notes |
|-------------|----------|-----------|-------|-------|
| **Raw telnet** | CP437 / Latin-1 bytes | chr(179), chr(196)... | ANSI SGR | Old BBS clients (SyncTERM, NetRunner), legacy apps |
| **SSH (modern)** | UTF-8 | U+2500 box drawing range | ANSI SGR (24-bit capable) | PuTTY, OpenSSH, iTerm2, Windows Terminal |
| **PETSCII (C64)** | PETSCII | Different char codes | C64 color codes | 40-column; rare; specialized |

### 1b. Detection signals

- **Telnet protocol**: Connection arrives on port 23; IAC negotiation; NAWS for size
- **SSH**: Connection on port 22; TERM env set; pty allocated; locale is UTF-8
- **`$TERM` env var**: `xterm-256color`, `vt100`, `dumb`, etc.
- **`$LANG`/`$LC_ALL`**: Contains `UTF-8` for Unicode-capable clients
- **NAWS (telnet)**: `IAC SB NAWS` sends terminal width/height
- **`stty size`**: Returns `rows cols` from the pty

### 1c. The key rule

**Pick your strategy at connection time and stick to it.**
- Telnet: output raw bytes; use CP437 for box chars; assume 80 columns
- SSH: output UTF-8; use U+2500 box drawing; query terminal size via ioctl or TIOCGWINSZ
- Never mix encoding strategies mid-session

---

## 2. ANSI ESCAPE SEQUENCES - COMPLETE REFERENCE

### 2a. Control Sequence Introducer (CSI) format

```
ESC [ <params> <final-byte>
```
- `ESC` = byte 0x1B (chr(27), `\e`, `\033`, `\x1b`)
- `<params>` = semicolon-separated numbers (optional)
- `<final-byte>` = letter that determines the command

### 2b. SGR color codes (most common)

```
ESC [ <code> m       # Set Graphic Rendition
```

**Reset:**
```
ESC[0m    # Reset ALL attributes
```

**Text styling:**
```
ESC[1m    # Bold
ESC[2m    # Dim / faint
ESC[3m    # Italic
ESC[4m    # Underline
ESC[5m    # Blink (slow)
ESC[7m    # Reverse video
ESC[8m    # Concealed / invisible
```

**Standard foreground colors (30-37):**
```
ESC[30m   # Black
ESC[31m   # Red
ESC[32m   # Green
ESC[33m   # Yellow
ESC[34m   # Blue
ESC[35m   # Magenta
ESC[36m   # Cyan
ESC[37m   # White
ESC[39m   # Default foreground
```

**Bright/intense foreground (90-97):**
```
ESC[90m   # Bright black (dark gray)
ESC[91m   # Bright red
ESC[92m   # Bright green
ESC[93m   # Bright yellow
ESC[94m   # Bright blue
ESC[95m   # Bright magenta
ESC[96m   # Bright cyan
ESC[97m   # Bright white
```

**Background colors (40-47, 100-107):** same offsets as foreground + 10

**256-color mode:**
```
ESC[38;5;<n>m   # Foreground: color index 0-255
ESC[48;5;<n>m   # Background: color index 0-255
```

**24-bit (truecolor):**
```
ESC[38;2;<r>;<g>;<b>m   # Foreground RGB
ESC[48;2;<r>;<g>;<b>m   # Background RGB
```

### 2c. Cursor movement

```
ESC[<n>A      # Move cursor up N rows
ESC[<n>B      # Move cursor down N rows
ESC[<n>C      # Move cursor right N columns
ESC[<n>D      # Move cursor left N columns
ESC[<r>;<c>H  # Move cursor to row R, column C (1-indexed)
ESC[H         # Move to home (top-left)
ESC[2J        # Clear screen
ESC[K         # Clear from cursor to end of line
ESC[0K        # Same as ESC[K
ESC[1K        # Clear from start of line to cursor
ESC[2K        # Clear entire current line
ESC[s         # Save cursor position
ESC[u         # Restore cursor position
```

### 2d. Common composed sequences

```
ESC[2J ESC[H    # Clear screen AND move to home (standard clear)
ESC[?25l        # Hide cursor
ESC[?25h        # Show cursor
ESC[?7h         # Enable line wrap
ESC[?7l         # Disable line wrap
ESC[?1049h      # Enter alternate screen buffer (save main screen)
ESC[?1049l      # Return to main screen buffer (restore on exit)
```

The alternate screen buffer (`ESC[?1049h` / `ESC[?1049l`) is the standard approach
for full-screen TUI apps. On entry, the terminal saves the current scrollback buffer
and presents a blank canvas. On exit, it restores exactly. Always restore on exit
(use atexit / signal handler / RAII destructor / END block).

### 2e. Spinner / progress sequences

Commonly used for CLI loading indicators. Write to stderr so stdout can be piped.

```python
# Overwrite the current line:
sys.stderr.write("\r  Loading...  ")   # \r returns to column 1
sys.stderr.flush()

# Erase current line then write new content:
sys.stderr.write("\r\x1b[K  Step 2/5 ...")

# Spinner characters (braille dots - most visually smooth, UTF-8 only):
SPINNER = ['|', '/', '-', '\\']  # ASCII - works everywhere

# Update pattern:
while working:
    sys.stderr.write(f"\r  {next(spinner)} Working...")
    sys.stderr.flush()
    time.sleep(0.1)
sys.stderr.write("\r\x1b[K")  # erase spinner when done
```

### 2f. Stripping ANSI for length calculations

To compute visual width of a colored string, remove all escape sequences first.
The canonical regex pattern (works in any language supporting regex):

```
# Remove CSI sequences (colors, cursor movement):
\e\[[0-9;]*[A-Za-z]

# Remove OSC sequences (hyperlinks, window title):
\e\][^\e]*\e\\   or   \e\][^\007]*[\007|\e\\]

# Remove other ESC sequences:
\e[^\[\]]

# Combined (greedy, cover all known ANSI/VT100 escapes):
\e(?:\[[0-9;]*[A-Za-z]|\][^\e]*(?:\e\\|\007)|[^\[\]])
```

After stripping, `len()` / `strlen()` / `length()` gives the visual character count
(for ASCII content; see section 6 for wide chars).

---

## 3. BOX DRAWING CHARACTERS

### 3a. The two character sets

**CP437 (single bytes, telnet/DOS):**

| Box element  | chr() | hex | glyph |
|--------------|-------|-----|-------|
| Horizontal   | 196   | C4  | -     |
| Vertical     | 179   | B3  | pipe  |
| Top-left     | 218   | DA  | +     |
| Top-right    | 191   | BF  | +     |
| Bottom-left  | 192   | C0  | +     |
| Bottom-right | 217   | D9  | +     |
| T-down       | 194   | C2  | +     |
| T-up         | 193   | C1  | +     |
| T-right      | 195   | C3  | +     |
| T-left       | 180   | B4  | +     |
| Cross        | 197   | C5  | +     |
| Dbl horiz    | 205   | CD  | =     |
| Dbl vert     | 186   | BA  | pipe  |
| Dbl top-left | 201   | C9  | +     |
| Dbl top-rt   | 187   | BB  | +     |
| Dbl bot-left | 200   | C8  | +     |
| Dbl bot-rt   | 188   | BC  | +     |

**Unicode UTF-8 (SSH/modern terminals):**

| Box element  | Unicode | UTF-8 bytes | glyph |
|--------------|---------|-------------|-------|
| Horizontal   | U+2500  | E2 94 80    | -     |
| Vertical     | U+2502  | E2 94 82    | pipe  |
| Top-left     | U+250C  | E2 94 8C    | +     |
| Top-right    | U+2510  | E2 94 90    | +     |
| Bottom-left  | U+2514  | E2 94 94    | +     |
| Bottom-right | U+2518  | E2 94 98    | +     |
| T-down       | U+252C  | E2 94 AC    | +     |
| T-up         | U+2534  | E2 94 B4    | +     |
| T-right      | U+251C  | E2 94 9C    | +     |
| T-left       | U+2524  | E2 94 A4    | +     |
| Cross        | U+253C  | E2 94 BC    | +     |
| Dbl horiz    | U+2550  | E2 95 90    | =     |
| Dbl vert     | U+2551  | E2 95 91    | pipe  |
| Dbl top-left | U+2554  | E2 95 94    | +     |
| Dbl top-rt   | U+2557  | E2 95 97    | +     |
| Dbl bot-left | U+255A  | E2 95 9A    | +     |
| Dbl bot-rt   | U+255D  | E2 95 9D    | +     |

### 3b. Drawing a standard box

```
+----------+        # ASCII fallback (any terminal)
| content  |
+----------+
```

**Width rule:** For a box spanning W visible columns, the horizontal line is `W - 2` chars
(subtract 2 for the corner characters on each end).

```
# Box of width 40:
top    = TL + (HORIZ * 38) + TR
middle = VL + (" " * 38) + VR
bottom = BL + (HORIZ * 38) + BR
```

### 3c. ASCII fallback (universally safe)

When targeting unknown/legacy terminals, use pure ASCII:
```
+----+    # corners
|    |    # sides
+----+
```
or just plain text with no box at all. Simpler is always more portable.

### 3d. Adaptive strategy (detect then branch)

```python
if client_is_ssh_utf8:
    H  = "\u2500"   # U+2500 horizontal line
    V  = "\u2502"   # U+2502 vertical line
    TL = "\u250C"   # etc.
else:
    H  = chr(196)   # CP437 horizontal line
    V  = chr(179)
    TL = chr(218)
```

```perl
# Perl: --utf8 flag selects SSH/Unicode path; default is CP437/telnet raw bytes.
# This is the canonical pattern for mockup/test scripts.
my $UTF8 = grep { $_ eq '--utf8' } @ARGV;
@ARGV    = grep { $_ ne '--utf8' } @ARGV;
if ($UTF8) { binmode(STDOUT, ':encoding(UTF-8)') }
else       { binmode(STDOUT, ':raw') }

my %BC = $UTF8
    ? (horizontal => "\x{2500}", vertical => "\x{2502}",
       topleft => "\x{250C}",   topright => "\x{2510}",
       bottomleft => "\x{2514}", bottomright => "\x{2518}",
       tdown => "\x{252C}", tup => "\x{2534}",
       tright => "\x{251C}", tleft => "\x{2524}", cross => "\x{253C}")
    : (horizontal => chr(196), vertical => chr(179),
       topleft => chr(218),    topright => chr(191),
       bottomleft => chr(192), bottomright => chr(217),
       tdown => chr(194), tup => chr(193),
       tright => chr(195), tleft => chr(180), cross => chr(197));

sub boxchar { $BC{$_[0]} // '?' }
my $H = boxchar('horizontal');
# Usage: ($H x 40) produces a 40-char horizontal line in the right encoding.
```

---

## 4. CP437 SPECIAL CHARACTERS

These are commonly used in BBS/game UIs. All are single bytes on telnet.

### 4a. Block characters

| Name         | chr() | hex | Notes |
|--------------|-------|-----|-------|
| Full block   | 219   | DB  | Used for big text, HP bars |
| Lower half   | 220   | DC  | Half-block shading |
| Upper half   | 223   | DF  | Half-block shading |
| Left half    | 221   | DD  | |
| Right half   | 222   | DE  | |
| Dark shade   | 178   | B2  | Dense fill |
| Medium shade | 177   | B1  | Medium fill |
| Light shade  | 176   | B0  | Light fill |
| Small square | 254   | FE  | Bullet |

### 4b. Suit symbols

| Suit     | chr() | hex |
|----------|-------|-----|
| Hearts   | 3     | 03  |
| Diamonds | 4     | 04  |
| Clubs    | 5     | 05  |
| Spades   | 6     | 06  |

### 4c. Arrow characters

| Arrow | chr() | hex | Caution |
|-------|-------|-----|---------|
| ->    | 26    | 1A  | |
| <-    | 27    | 1B  | Same byte as ESC! Avoid in ANSI contexts |
| ^     | 24    | 18  | |
| v     | 25    | 19  | |

### 4d. Unicode equivalents for SSH (3 bytes each in UTF-8)

| CP437        | Unicode | hex bytes |
|--------------|---------|-----------|
| Full block (219)  | U+2588 | E2 96 88 |
| Lower half (220)  | U+2584 | E2 96 84 |
| Upper half (223)  | U+2580 | E2 96 80 |
| Dark shade (178)  | U+2593 | E2 96 93 |
| Medium shade (177)| U+2592 | E2 96 92 |
| Light shade (176) | U+2591 | E2 96 91 |

---

## 5. VISUAL ALIGNMENT - THE ANSI WIDTH PROBLEM

### 5a. The problem

Padding functions (`printf "%-20s"`, Python `.ljust(20)`, Go `fmt.Sprintf("%-20s", ...)`)
count **bytes** or **string length** - not **visual columns**. ANSI escape codes are
invisible on screen but consume bytes/characters in the string, causing misalignment.

```
colored_string = "\x1b[34m" + "Alice" + "\x1b[0m"
# String length: 15 bytes (5 ESC-code + 5 text + 5 ESC-code)
# Visual width:  5 columns

# Wrong:
printf("%-15s|", colored_string)   # output: "Alice     |" (10 spaces too few)

# Right:
visual_len = len(strip_ansi(colored_string))   # = 5
padding = max(0, 20 - visual_len)
print(colored_string + " " * padding + "|")    # correct
```

### 5b. The two correct patterns

**Pattern 1 - Pad plain, then colorize (preferred):**
```
# Truncate plain text to max width
name = plain_name[:20]
# Pad plain text to exact width
padded = name.ljust(20)
# Apply color to already-padded string
output = COLOR_CODE + padded + RESET_CODE
```

**Pattern 2 - Colorize, then measure stripped, then add spaces:**
```
# Build the colorized string however you need
colored = build_colored_string(data)
# Measure visual width from stripped version
vis_width = len(strip_ansi(colored))
# Pad with spaces to reach column width
output = colored + " " * max(0, COL_WIDTH - vis_width)
```

**Pattern 3 - Track visible width at build time (multi-column boards):**
```
# Build each cell as (colored_string, visible_width) tuple
cells = []
for item in data:
    plain_text = str(item)                    # compute length from plain
    vis_len = len(plain_text) + PREFIX_LEN    # count chars manually
    colored = color(item) + plain_text + RESET
    cells.append((colored, vis_len))

# Pad each cell to column width:
for colored, vis_len in cells:
    padding = max(0, COL_WIDTH - vis_len)
    output_row += colored + " " * padding
```

### 5c. Strip ANSI implementation (any language)

The regex to strip all ANSI/VT100 escape sequences:

```python
# Python
import re
ANSI_RE = re.compile(r'\x1b(?:\[[0-9;]*[A-Za-z]|\][^\x1b]*(?:\x1b\\|\x07)|[^\[\]])')
def strip_ansi(s):
    return ANSI_RE.sub('', s)
```

```go
// Go
var ansiRE = regexp.MustCompile(`\x1b(?:\[[0-9;]*[A-Za-z]|\][^\x1b]*(?:\x1b\\|\x07)|[^\[\]])`)
func stripANSI(s string) string { return ansiRE.ReplaceAllString(s, "") }
```

```javascript
// JavaScript
const ANSI_RE = /\x1b(?:\[[0-9;]*[A-Za-z]|\][^\x1b]*(?:\x1b\\|\x07)|[^\[\]])/g;
const stripANSI = s => s.replace(ANSI_RE, '');
```

```rust
// Rust (with regex crate)
static ANSI_RE: &str = r"\x1b(?:\[[0-9;]*[A-Za-z]|\][^\x1b]*(?:\x1b\\|\x07)|[^\[\]])";
```

```swift
// Swift
let ansiPattern = #"\e(?:\[[0-9;]*[A-Za-z]|\][^\e]*(?:\e\\|\u{07})|[^\[\]])"#
let ansiRE = try! NSRegularExpression(pattern: ansiPattern)
func stripANSI(_ s: String) -> String {
    let range = NSRange(s.startIndex..., in: s)
    return ansiRE.stringByReplacingMatches(in: s, range: range, withTemplate: "")
}
```

```perl
# Perl
sub strip_ansi {
    my $text = $_[0];
    $text =~ s/\e\[[0-9;]*[A-Za-z]//g;  # CSI sequences
    $text =~ s/\e\][^\e\a]*(?:\a|\e\\)//g;  # OSC sequences (BEL or ST terminated)
    $text =~ s/\e[^\[\]]//g;                 # Other bare ESC sequences
    return $text;
}
```

### 5d. The off-by-two trap in bars with bracket characters

HP/progress bars often print bracket characters alongside the colored bar:

```
# WRONG - bracket chars counted in visible width but added outside the padding call:
bar = vpad(hp_bar(hp, max_hp, 20), 22) + f" {hp}/{max_hp}"
# The "[" before and "]" after are outside the padding calculation
# but still consume 2 visible columns -> column lines up wrong.

# RIGHT - include bracket chars inside the padding width calculation:
bar = vpad("[" + hp_bar(hp, max_hp, 20) + "]", 24) + f" {hp}/{max_hp}"
# vpad() strips ANSI from the full "[###---]" string to measure width correctly.
```

**Rule:** When measuring a colored string for column alignment, include every
character that will be printed in the same column slot - brackets, prefix labels,
everything. Strip ANSI from the complete string, not just the colored portion.

---

## 6. WIDE CHARACTERS (CJK, EMOJI)

Some Unicode characters occupy **2 terminal columns** instead of 1. This affects
visual width calculations even after ANSI stripping.

### 6a. Double-width character ranges

| Range | Description |
|-------|-------------|
| U+1100 - U+11FF | Hangul Jamo |
| U+2E80 - U+2EFF | CJK Radicals |
| U+3000 - U+303F | CJK Symbols and Punctuation |
| U+3040 - U+309F | Hiragana |
| U+30A0 - U+30FF | Katakana |
| U+4E00 - U+9FFF | CJK Unified Ideographs (main block) |
| U+AC00 - U+D7AF | Hangul Syllables |
| U+FF01 - U+FF60 | Fullwidth Forms |
| U+1F300 - U+1FAFF | Emoji |
| U+20000 - U+2FFFF | CJK Extension B-F |

### 6b. Visual width function (language-agnostic logic)

```
function visual_width(text):  # text is already stripped of ANSI
    width = 0
    for each codepoint cp in text:
        if cp < 0x20 or cp == 0x7F:
            pass  # control character, zero width
        elif is_double_width(cp):
            width += 2
        else:
            width += 1
    return width
```

Use `wcswidth()` from POSIX (C), `wcwidth()` per char, or Unicode-aware libraries:
- Python: `wcwidth` package (`pip install wcwidth`)
- Go: `go-runewidth` (`golang.org/x/text/width`)
- Rust: `unicode-width` crate
- JavaScript: `string-width` package

### 6c. Practical advice

- **Avoid wide chars in narrow terminals.** A 3-char CJK word takes 6 columns.
- **Emoji are especially dangerous:** vary between 1 and 2 wide depending on terminal.
- **For BBS/game UI, restrict to ASCII + CP437 or ASCII + simple Latin.**
- Always use `visual_width(strip_ansi(s))` not `len(s)` when measuring for column layout.

---

## 7. BYTE ENCODING AND TERMINAL I/O

### 7a. The encoding pipeline

```
Your code -> string buffer -> encoding layer -> bytes -> socket/pty -> terminal
```

| Step | Telnet | SSH |
|------|--------|-----|
| String buffer | bytes (Latin-1) | Unicode / UTF-8 |
| Encoding layer | none / raw | UTF-8 encode |
| Bytes on wire | 1 byte per char (for 0x00-0xFF) | 1-4 bytes per char |
| Terminal decodes as | CP437 or Latin-1 | UTF-8 |

### 7b. Critical rules by language

**Languages with separate byte/string types (Go, Rust, Swift, Java):**
- Use `[]byte` / `Vec<u8>` / `Data` for raw CP437 output
- Use `String` (UTF-8) for SSH output
- Do NOT use string formatting functions on byte slices for layout math

**Languages where strings are byte arrays (C):**
- `strlen()` = byte count = visual width for ASCII
- `strlen()` != visual width once ANSI codes or multibyte chars are involved
- Always use a stripped, pure-ASCII string for `printf("%-*s", width, str)` padding

**Languages where strings are Unicode sequences (Python 3, JavaScript, Swift, Ruby):**
- `len()` / `.length` / `.count` = character count = visual width for ASCII
- ANSI escape chars are regular characters and inflate the count
- Strip ANSI before measuring, then re-apply color after padding

**Perl (no strict mode):**
- Without `use utf8`: `chr(N)` for N <= 255 = 1 raw byte, `length()` = byte count
- With `use utf8`: same for N <= 255; for N > 255, string is UTF-8 flagged
- To `:raw` filehandle: chr(0-255) always 1 byte; chr(256+) = 3-4 bytes UTF-8

### 7c. Output mode setup

For **telnet (raw bytes)**:

```c
// C: just write() bytes
write(STDOUT_FILENO, buf, n);

// Set terminal to raw mode:
struct termios raw = {0};
tcgetattr(STDIN_FILENO, &raw);
raw.c_iflag &= ~(ICRNL | IXON);
raw.c_lflag &= ~(ECHO | ICANON);
tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
```

```python
# Python: write bytes directly
import sys
sys.stdout.buffer.write(b"\x1b[34m" + b"text" + b"\x1b[0m")
```

```go
// Go: write to os.Stdout (already bytes)
fmt.Fprint(os.Stdout, "\x1b[34mtext\x1b[0m")
```

For **SSH (UTF-8 text)**:

Most SSH libraries provide a PTY/channel that accepts UTF-8 strings. Write UTF-8
encoded bytes. Ensure your terminal size comes from the PTY `TIOCGWINSZ` request.

**Perl-specific: NEVER use `use open ':encoding(UTF-8)'` on a telnet path.**

`use open ':std', ':encoding(UTF-8)'` wraps STDOUT with a UTF-8 encoding layer.
Every `print` call now re-encodes your bytes. If `boxchar()` returns `chr(196)`
(the CP437 `─` byte, 0xC4), Perl encodes it as UTF-8: `C3 84` (two bytes: Ã Ä).
A CP437 telnet terminal sees garbled text: `ÎÃ¶ÃÎÃ¶Ã` instead of `─────`.

```perl
# WRONG - puts a UTF-8 encoding layer on stdout:
use open ':std', ':encoding(UTF-8)';

# RIGHT for CP437/telnet: raw binary output (the default if you don't set anything):
binmode(STDOUT, ':raw');

# RIGHT for SSH/UTF-8 (only when client supports Unicode):
binmode(STDOUT, ':encoding(UTF-8)');  # then use "\x{2500}" not chr(196)

# Pattern for mockup scripts that support both modes:
my $UTF8 = grep { $_ eq '--utf8' } @ARGV;
@ARGV = grep { $_ ne '--utf8' } @ARGV;
if ($UTF8) { binmode(STDOUT, ':encoding(UTF-8)') }
else       { binmode(STDOUT, ':raw') }
my $HZ = $UTF8 ? "\x{2500}" : chr(196);  # ─
my $VT = $UTF8 ? "\x{2502}" : chr(179);  # │
```

### 7d. The CP437 telnet vs UTF-8 SSH mismatch

When the same code serves both telnet and SSH clients:

```
CP437 byte 0xC4 (chr(196)) in a telnet terminal -> displays as - (horizontal line)
CP437 byte 0xC4 in a UTF-8 SSH terminal -> displays as A-umlaut
```

Solutions:
1. **Detect at connection time** (preferred) - send CP437 to telnet, UTF-8 box chars to SSH
2. **ASCII fallback** - use `-`, `|`, `+` everywhere (no mismatch possible)
3. **Library dispatch** - a `box_char(name, encoding)` function that selects the right char

---

## 8. TERMINAL SIZE AND BUDGET

### 8a. Getting terminal dimensions

```c
// C: ioctl
#include <sys/ioctl.h>
struct winsize ws;
ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);
int cols = ws.ws_col;
int rows = ws.ws_row;
```

```python
# Python
import shutil
cols, rows = shutil.get_terminal_size(fallback=(80, 24))
```

```go
// Go (golang.org/x/term)
cols, rows, err := term.GetSize(int(os.Stdout.Fd()))
```

```javascript
// Node.js
const cols = process.stdout.columns || 80;
const rows = process.stdout.rows || 24;
```

**Always provide a fallback** - pipes and non-interactive environments return 0 or error.
Fallback: `cols = 80, rows = 24` (lowest common denominator).

You can also read from environment variables set by the shell: `$COLUMNS`, `$LINES`.
`tput cols` and `tput lines` query the terminfo database and work in shell scripts.

### 8b. The 24-line terminal budget

Classic BBS/game constraint: **24 visible rows** (standard VT100/telnet screen).

```
Row  1: Title / game name
Row  2: Horizontal separator
Rows 3-N: Content (your game data)
Row N+1: Empty line
Rows N+2 to 22: Command list / controls
Row 23: Horizontal separator
Row 24: Input prompt
```

Design tip: **content area = 24 - overhead_rows**. Count title + separator + prompt lines
first, then allocate remaining rows to game content. Never let content overflow without
scrolling.

**Prompt discipline - the final line rule:**

The input prompt must be the very last output, with no trailing newline. Commands and the
prompt can share a single line when space is tight:

```
# WRONG - prompt on row 25:
print("  A ... Attack    S ... Spell\n")   # newline pushes prompt to next row
print("  Action: ")                         # row 25 - terminal scrolls!

# RIGHT - combined on row 24 (no newline before the prompt):
print("  A ... Attack    S ... Spell    Action: ")  # single line, no trailing \n
```

Count lines with `grep -c ""` or `wc -l` during development. The prompt line with
no trailing newline still counts as a line - aim for exactly 24 in total output.

### 8b-2. The 79-column rule

**Use 79 visible columns, not 80.** Classic 80-column terminals display 80 characters
per row, but column 80 is used by the cursor/newline. Writing to column 80 can cause
line-wrapping or garbled output on some clients.

```
# WRONG:
W = 80
top_border = TL + HORIZ * (W - 2) + TR   # 80 chars total -> may wrap

# RIGHT:
W = 79
top_border = TL + HORIZ * (W - 2) + TR   # 79 chars total -> safe
```

**For BBS/telnet defaults:** W=79 (content), with `\n` or `\r\n` as the 80th byte.
**For SSH/modern terminals:** Query actual width; default to 79 if unknown.

### 8c. Fixed-height display blocks

**Variable-height blocks cause line count instability**. When optional content (buffs, items,
messages) can appear or disappear, the screen layout shifts unexpectedly.

**Rule:** Every display section must have a fixed line count.
- Put optional data on an existing line as a suffix (`[POISON]`, `[LIMIT]`)
- Never add an optional row that appears sometimes
- When in doubt, always render the row and leave it blank when not applicable

```python
# WRONG - variable height:
if player.poisoned:
    print("POISONED")   # row appears sometimes -> layout shifts

# RIGHT - fixed height, always render:
status = "POISONED" if player.poisoned else ""
print(f"Status: {status:<20}")  # always exactly 1 row
```

---

## 9. TEXT LAYOUT PATTERNS

### 9a. Menu item format

The standard key-to-description format used in terminal menus:

```
  A ... Action one
  B ... Another action
  Q ... Quit
```

Pseudocode:
```
for item in menu_items:
    print("  " + key_color + item.key + reset + " ... " + item.description)
```

### 9b. Label: Value pairs

```
  Balance:      $1,250
  Level:        12
  Hit Points:   45/80
```

Rules:
- Use fixed-width labels: `f"{label:<12}"` or `"%-12s" % label`
- Right-align numeric values in their column
- Never mix plain and colored strings in the same `printf` column spec

### 9c. Columnar / tabular data

```
  Name           Level   HP        Location
  -----------------------------------------
  Alice          12      45/80     Forest
  Bob            8       22/40     Town
```

**Key rule:** Compute `padded` from plain `text`, then apply color.
Never `printf("%-15s", colored)`.

```python
# COLUMNS = [(name, width, align), ...]
for row in data:
    cells = []
    for i, (col_name, col_w, align) in enumerate(COLUMNS):
        text = str(row[i])[:col_w]  # truncate to col width
        padded = text.ljust(col_w) if align == "left" else text.rjust(col_w)
        cells.append(color(row[i]) + padded + reset)
    print("  " + "  ".join(cells))
```

### 9d. Two-column layout

```
  A ... Action one        G ... Action seven
  B ... Action two        H ... Action eight
```

Pseudocode:
```
COL_WIDTH = terminal_cols // 2 - 2
half = (len(items) + 1) // 2

for i in range(half):
    left = items[i]
    right = items[i + half] if i + half < len(items) else None

    left_str = build_colored_item(left)
    left_vis = visual_length_of_plain(left)   # computed from plain
    padding = max(1, COL_WIDTH - left_vis)

    if right:
        print(left_str + " " * padding + build_colored_item(right))
    else:
        print(left_str)
```

**Critical alignment constraint:** `build_colored_item(left)` MUST produce the
same visible width as `left_vis` for every item, including variable-length
fields. If an item's name/description is formatted with `sprintf("%-18s", name)`
in the plain version, the colored version must apply the SAME padding:

```perl
# WRONG - colored version omits the %-18s padding:
my $plain   = sprintf("  %s ... %-18s x%d", $key, $name, $qty);  # always 30 chars
my $colored = "  " . $CYAN . $key . $RST . " ... " . $name . "  " . $DIM . "x$qty" . $RST;
# $plain is 30 chars but $colored renders as 22-30 chars (name varies) -> misalignment

# CORRECT - colored version pads name identically:
my $name_padded = sprintf("%-18s", $name);   # fixed 18 chars
my $colored = "  " . $CYAN . $key . $RST . " ... " . $name_padded . "  " . $DIM . "x$qty" . $RST;
# Now colored renders same visible width as plain for every item
```

For simple items (key + description only, no padding), use fixed description
width in the colored version with an optional `$desc_width` param:

```perl
sub menu_item {
    my ($key, $desc, $desc_width) = @_;
    my $label = $desc_width ? sprintf("%-${desc_width}s", substr($desc, 0, $desc_width)) : $desc;
    return "  " . $CYAN . $key . $RST . " ... " . $label;
}
# For two-column use, pass $desc_width to all but the last item per row:
print menu_item("A", "Attack", 8) . "   " . menu_item("S", "Spell") . "\n";
print menu_item("R", "Run",    8) . "   " . menu_item("D", "Defend") . "\n";
```

**WARNING:** `sprintf("%-Ns", $str)` only pads UP TO N chars - it does NOT
truncate strings LONGER than N. A description of 26 chars with `$desc_width=22`
will output 26 chars and shift the right column 4 positions. Always use `substr`
before `sprintf` to enforce the maximum width:

```perl
# WRONG - overflows if desc is longer than desc_width:
sprintf("%-${desc_width}s", $desc)

# RIGHT - truncates then pads, always exactly desc_width chars:
sprintf("%-${desc_width}s", substr($desc, 0, $desc_width))
```

### 9e. HP / progress bar

Pure ASCII approach (works on every terminal):

```python
def hp_bar(current, max_hp, width=20):
    max_hp = max(1, max_hp)
    pct = max(0.0, min(1.0, current / max_hp))
    filled = int(pct * width)
    bar = "#" * filled + "-" * (width - filled)
    if pct > 0.5:    color = GREEN
    elif pct > 0.25: color = YELLOW
    else:            color = RED
    return f"{color}[{bar}]{reset} {current}/{max_hp}"
```

Unicode block bar (SSH/UTF-8 only):
```python
bar = "\u2588" * filled + "\u2591" * (width - filled)  # U+2588, U+2591
```

### 9f. Centered text

```python
def center(text, width=80):
    plain = strip_ansi(text)
    vis_len = visual_width(plain)  # or len(plain) for ASCII-only
    pad = max(0, (width - vis_len) // 2)
    return " " * pad + text
```

---

## 10. ACTION LOG PATTERN

Used in multiplayer/real-time games to show what happened between player turns
without redrawing the full board.

### 10a. The pattern

```python
class Game:
    def __init__(self):
        self.action_log = []   # accumulated events

    def ai_turn(self, player):
        # AI acts silently - accumulate, don't display
        result = player.take_action()
        self.action_log.append(f"{player.name} {result}")

    def human_turn_start(self, player):
        # Show everything AI did since last human turn:
        for event in self.action_log:
            print("  " + event)
        self.action_log.clear()
        # Now prompt human player

    def round_start(self):
        self.action_log.clear()  # reset between rounds
```

### 10b. Display budget for action log

```
# In a 24-line terminal with a 3-row game board and 5-row hand display:
# Total:        24 rows
# Title:         1
# Separators:    3
# Game board:    3
# Hand rows:     5
# Prompt:        1
# -----------------
# Available:    11 rows for action log

# Rule: limit log to (num_players - 1) entries max
# Human's own actions aren't logged (they know what they did)
max_log_lines = num_players - 1
display_log = action_log[-max_log_lines:]  # take latest N
```

### 10c. Rules

1. **Never redraw the board** for AI actions between human turns - accumulate log
2. **Do not log human's own actions** - they just played, they know
3. **Reset log** at round/hand boundaries
4. **Keep log short** - 1 to (num_players - 1) lines
5. **AI acts instantly** - no per-action display; show all on next human turn

---

## 11. ANSI DETECTION AND CAPABILITY NEGOTIATION

### 11a. Basic detection signals

| Signal | Meaning | How to detect |
|--------|---------|---------------|
| `$TERM` = `dumb` | No ANSI support | env var |
| `$TERM` = `xterm*` | Full ANSI + 256 colors | env var |
| `$TERM` = `vt100` | Basic ANSI | env var |
| `$NO_COLOR` set | User requests no color (honor it) | env var (see no-color.org) |
| `$COLORTERM` = `truecolor` | 24-bit color support | env var |
| stdout not a TTY | Piped output; suppress color | `isatty()` |
| Telnet NAWS | Client sends terminal size | telnet IAC negotiation |
| SSH TERM env | Forwarded in PTY setup | pty/session setup |

### 11b. The `isatty()` check

Always check if stdout is a terminal before emitting ANSI codes:

```python
import sys, os
use_color = sys.stdout.isatty() and os.environ.get('NO_COLOR') is None

def colorize(text, code):
    if use_color:
        return f"\x1b[{code}m{text}\x1b[0m"
    return text
```

```go
import "golang.org/x/term"
useColor := term.IsTerminal(int(os.Stdout.Fd()))
```

```c
#include <unistd.h>
int use_color = isatty(STDOUT_FILENO);
```

### 11c. Telnet IAC / NAWS negotiation (simplified)

```
Client sends: IAC WILL NAWS       (client supports window size)
Server replies: IAC DO NAWS       (server wants window size)
Client sends: IAC SB NAWS <W_high> <W_low> <H_high> <H_low> IAC SE

IAC = 0xFF, WILL = 0xFB, NAWS = 0x1F, DO = 0xFD, SB = 0xFA, SE = 0xF0
```

Parse the NAWS subnegotiation to get terminal cols/rows dynamically.

### 11d. Detecting 256-color and truecolor support

```python
import os
term = os.environ.get('TERM', '')
colorterm = os.environ.get('COLORTERM', '')

if 'truecolor' in colorterm or '24bit' in colorterm:
    color_depth = 24   # full RGB
elif '256color' in term or colorterm:
    color_depth = 8    # 256 palette
elif 'color' in term or term.startswith('xterm'):
    color_depth = 4    # 16 colors (8 + bold)
else:
    color_depth = 0    # no color
```

---

## 12. COMMON MISTAKES

### 12a. sprintf / printf on ANSI-colored strings

```python
# WRONG:
colored = "\x1b[34m" + name + "\x1b[0m"
padded = colored.ljust(20)   # pads by len() which includes escape codes

# RIGHT:
padded_plain = name.ljust(20)     # pad plain
colored = "\x1b[34m" + padded_plain + "\x1b[0m"  # then colorize
```

### 12b. CP437 box chars for SSH clients

```python
# WRONG for SSH - raw CP437 byte 0xC4 displayed as A-umlaut in UTF-8 terminal:
line = chr(196) * 40   # only correct for telnet

# RIGHT - detect and branch:
if client.is_ssh:
    line = "\u2500" * 40     # U+2500 horizontal line
else:
    line = chr(196) * 40     # CP437 horizontal line

# Or use ASCII for universal compatibility:
line = "-" * 40
```

### 12c. Hardcoded terminal width

```python
# WRONG:
separator = "-" * 78

# RIGHT:
cols = get_terminal_width()  # default 80
separator = "-" * (cols - 2)
```

### 12d. Variable-height display blocks

```python
# WRONG - causes layout shift when buffs appear/disappear:
def draw_player(p):
    print(p.name)
    if p.poisoned:
        print("  [POISONED]")   # optional row - breaks fixed layout!

# RIGHT - fixed 2 rows always:
def draw_player(p):
    tags = "[POISONED]" if p.poisoned else ""
    print(p.name + " " + tags)  # always 1 line
    print(f"HP: {p.hp}/{p.max_hp}")
```

### 12e. Forgetting to reset color at end of output

```python
# WRONG:
print("\x1b[34mBlue text")          # color bleeds into next line

# RIGHT:
print("\x1b[34mBlue text\x1b[0m")   # always reset
```

### 12f. Not stripping ANSI before truncating

```python
# WRONG - might truncate mid-escape-code:
s = colored_string[:20]  # could cut inside "\x1b[34m"

# RIGHT - strip, truncate, re-apply:
plain = strip_ansi(colored_string)[:20]
redisplay = colorize(plain, color_code)
```

### 12g. Unicode string literals without encoding awareness

```python
# WRONG in Python 2 / C without careful handling:
line = "\u2500" * 40   # contains U+2500, will be multi-byte bytes

# RIGHT - know your string type:
# Python 3: str is Unicode, .encode('utf-8') gives bytes for wire
# C: use u8"..." for UTF-8 literal, or "\xe2\x94\x80" explicitly
# Go: string literals are UTF-8, len() = bytes, len([]rune(s)) = chars
```

### 12h. Measuring bytes instead of characters

| Language | Byte count | Character count | Visual width |
|----------|-----------|----------------|--------------|
| C | `strlen(s)` | requires wcslen or loop | requires wcwidth loop |
| Python 3 | `len(s.encode())` | `len(s)` | use `wcwidth` library |
| Go | `len(s)` | `len([]rune(s))` | use `go-runewidth` |
| JavaScript | (no native) | `s.length` (UTF-16 units) | use `string-width` |
| Rust | `s.len()` | `s.chars().count()` | use `unicode-width` |
| Perl | `length(s)` (bytes or chars per utf8 flag) | same | use wcswidth or loop |

### 12i. Mixing colorized and plain padding in the same printf

```
# WRONG - width includes ANSI escape bytes:
printf("%-22s %s\n", colored_bar, "$hp/$max_hp");

# RIGHT - only pad with spaces after measuring visible width:
padding = " " * max(0, 22 - vis_len(colored_bar));
print(colored_bar + padding + " $hp/$max_hp");
```

### 12j. Using W=80 instead of W=79

```
# WRONG - box is exactly 80 columns, hitting terminal edge:
W = 80
print(TL + HORIZ * (W - 2) + TR)  # may wrap on 80-col terminal

# RIGHT:
W = 79
print(TL + HORIZ * (W - 2) + TR)  # safe
```

### 12k. Prompt on row 25 after commands on row 24

```
# WRONG - three output lines = 3 rows, prompt falls to row 25:
print "  Q ... Quit    E ... Equip\n"    # row 23
print "  S ... Spell\n"                  # row 24 with newline
print "  Choice: "                       # row 25! terminal scrolls

# RIGHT - commands and prompt on the same final line, no newline:
print "  Q ... Quit    E ... Equip    S ... Spell    Choice: "  # row 24
```

### 12l. Not honoring NO_COLOR

```python
# WRONG - ignoring user's explicit preference:
print("\x1b[34mBlue text\x1b[0m")  # always colored

# RIGHT - check NO_COLOR env var (no-color.org standard):
import os
use_color = sys.stdout.isatty() and 'NO_COLOR' not in os.environ
```

---

### 12m. Two-column: colored version doesn't match plain width

When building a two-column layout via `left_vis = visual_length_of_plain(left)`,
the COLORED version must produce the **same** visible width as the plain version
for EVERY item. If the colored version omits a `sprintf` padding that exists in
the plain version, different items produce different visible widths -> misalignment.

```perl
# WRONG - plain pads name to 18 chars, but colored doesn't:
my $plain   = sprintf("  %s ... %-18s x%d", $key, $name, $qty);  # always 30 vis
my $colored = "  " . $CYAN . $key . $RST . " ... " . $name . " x$qty" . $RST;
# "Iron Sword" renders 22 vis, "Leather Armor" renders 25 vis -> right col drifts

# RIGHT - apply the same %-Ns in the colored version:
my $np = sprintf("%-18s", $name);  # fixed 18 chars
my $plain   = "  $key ... $np x$qty";
my $colored = "  " . $CYAN . $key . $RST . " ... " . $np . " x$qty" . $RST;
# Always 30 vis -> right column stays anchored
```

**Rule:** Every variable-length component must be padded to a fixed width in
both the plain and colored strings before you measure/use them for alignment.

---

## 13. COLOR CONVENTION TABLE

These conventions create visual consistency across a terminal UI:

| Element | Recommended color | Notes |
|---------|------------------|-------|
| Game/screen title | Bold + primary color | The "brand" of each screen |
| Section headers | Primary color | Subdued, not garish |
| Separator lines / borders | Dark / dim | Structural; should recede |
| Label text ("Balance:", "HP:") | Neutral / system color | Let values pop |
| Player names, key data | Bright color (user color) | Most important data |
| Win / success messages | Green or bright | Positive outcome |
| Monetary values, scores | Yellow or data color | Numbers need visibility |
| Command keys (A, B, Q...) | Bright / prompt color | Actionable items |
| Error / danger messages | Red | Universal danger signal |
| HP bar: high (>50%) | Green | Good |
| HP bar: medium (25-50%) | Yellow | Caution |
| HP bar: low (<25%) | Red | Danger |
| News / log messages | Dim / system color | Background context |
| Online player list | User color | People = prominent |
| Face-down / unknown | Dim / line color | Hidden = recede |
| Currently selected | Bright / user color | Focus = prominent |

**Rule:** Use at most 4-5 distinct colors in any single display. More creates noise.

---

## 14. PRE-IMPLEMENTATION CHECKLIST

Before writing any new terminal display function:

- [ ] What client types must this support? Telnet only? SSH only? Both?
- [ ] What character set will you use? ASCII (safest), CP437 (telnet), Unicode (SSH)
- [ ] Do you have the terminal width? Use dynamic value; default W=79 for BBS, not 80
- [ ] How many lines does this consume? Count exactly. Will it fit in 24 rows?
- [ ] Is the height fixed? Variable-height blocks break multi-screen layouts
- [ ] Where does color live? Apply after padding, strip before measuring
- [ ] Are you using sprintf/printf/format on colored strings? Don't - pad plain first
- [ ] Do you reset color at the end of each line? If not, color bleeds
- [ ] Do any items truncate? Truncate plain text BEFORE applying color
- [ ] Is there a fallback for no-ANSI terminals? Check $TERM, isatty(), $NO_COLOR
- [ ] Are bracket chars inside your padding measurement? Off-by-two if not
- [ ] Does the prompt line end without a trailing newline? Row 25 scroll if it does
- [ ] Verified actual column widths? Strip ANSI and measure each row to confirm

---

*For PhotonBBS / Perl-specific implementation of these concepts, see the bbs-terminal-display skill.*
