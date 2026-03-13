---
name: "bbs-terminal-display"
description: "PhotonBBS / Perl-specific terminal display reference: @-code color system, boxchar() API, CP437/UTF-8 dispatch, visual alignment in Perl, pb-doorlib graphics (cards/dice/slots), 24-line budget, and PhotonBBS-specific common mistakes. Requires ansi-terminal-display for the universal concepts."
version: "1.0.0"
author: "Fewtarius"
tools: ["file_operations", "terminal_operations"]
depends: ["ansi-terminal-display"]
---

# PhotonBBS Terminal Display - Perl Implementation

PhotonBBS-specific reference for terminal display: the @-code substitution
system, `boxchar()` API, CP437/UTF-8/PETSCII dispatch, visual alignment in
Perl, and working code patterns drawn directly from the codebase.

For universal concepts (ANSI escape codes, box drawing tables, wide chars,
encoding theory), see the `ansi-terminal-display` skill.

---

## TABLE OF CONTENTS

1. [The Two Terminal Worlds (PhotonBBS)](#1-the-two-terminal-worlds)
2. [Color System - @-Codes and Runtime Variables](#2-color-system)
3. [Box Drawing - boxchar() API](#3-box-drawing)
4. [Text Layout Patterns](#4-text-layout-patterns)
5. [CP437 Special Characters](#5-cp437-special-characters)
6. [Big Text Engine (pb-bigtext)](#6-big-text-engine)
7. [Markdown Rendering (pb-render) - When NOT to use](#7-markdown-rendering)
8. [Visual Alignment - The ANSI Width Problem in Perl](#8-visual-alignment)
9. [pb-doorlib Graphics (cards, dice, slots)](#9-pb-doorlib-graphics)
10. [Action Log Pattern](#10-action-log-pattern)
11. [Common Mistakes](#11-common-mistakes)
12. [ANSI Detection and Capabilities](#12-ansi-detection)
13. [Working Examples](#13-working-examples)
14. [Color Usage Conventions](#14-color-usage-conventions)
15. [Checklist Before Writing a Display Function](#15-checklist)

---

## 1. THE TWO TERMINAL WORLDS

Everything in PhotonBBS display must work in two very different contexts:

| Property | Telnet (Port 23) | SSH (Port 2222) |
|----------|-----------------|----------------|
| Protocol | Raw TCP + telnet negotiation | SSH with PTY |
| Encoding | CP437 (single bytes, 0x00-0xFF) | UTF-8 (multi-byte sequences) |
| Width | 80 or 40 (C64 PETSCII) columns | 80+ columns typically |
| Box chars | CP437: chr(196), chr(179)... | UTF-8: U+2500 range |
| Big text chars | CP437: chr(219-223), chr(176-178) | Unicode quadrant blocks |
| Detection | `$info{'proto'}` eq 'SSH' | `$info{'proto'}` eq 'SSH' |

**PETSCII** (C64 40-column): detected by `$config{'terminal_width'} == 40`. Uses
completely different character values for box drawing (chr(64), chr(93), etc).

**Key rule:** Never hardcode box drawing or special characters. Always use
`boxchar()` (for framework code) or `_box()` / `_bt_char()` (for render/bigtext),
which dispatch based on `$info{'proto'}` and `$config{'terminal_width'}`.

---

## 2. COLOR SYSTEM

### 2a. The @-code system (pb-framework)

All colors are applied via four centralized substitution functions called by
`writeline()`, `readfile()`, `colorline()`, and `applytheme()`. NEVER add
inline `s///` chains - always route through these:

```perl
_substitute_color_codes($str)   # @RST @BLK @RED @GRN @YLW @BLU @MAG @CYN @WHT
                                 # @BBLK @BRED @BGRN @BYLW @BBLU @BMAG @BCYN @BWHT
_substitute_theme_codes($str)   # @SYSTEMCLR @USERCLR @THEMECOLOR @DATACLR
                                 # @PROMPTCLR @INPUTCLR @LINECOLOR @ERRORCLR
_substitute_box_codes($str)     # @BOXHORIZ@ @BOXVERT@ etc -> boxchar() calls
_substitute_template_vars($str) # @USER @SYSNM @TIME @DATE etc
```

### 2b. Runtime color variables

Set at session start from `%config`. Available globally in all modules:

```perl
$RST   # ANSI reset (from @RST)

$config{'themecolor'}   # Primary accent color (screen titles, section headers)
$config{'datacolor'}    # Secondary data/values (scores, numbers)
$config{'usercolor'}    # Usernames, player names, wins, currently selected
$config{'systemcolor'}  # System messages, label text
$config{'errorcolor'}   # Errors, danger, red elements, low HP
$config{'promptcolor'}  # Command keys, prompts
$config{'inputcolor'}   # User input text
$config{'linecolor'}    # Borders, separators, faint/background text
```

### 2c. ANSI escape sequences (raw, for when you need them directly)

```perl
# ESC = chr(27) = "\e" = "\033" = "\x1b"
"\e[0m"         # Reset all attributes
"\e[1m"         # Bold
"\e[2m"         # Dim
"\e[4m"         # Underline
"\e[5m"         # Blink
"\e[7m"         # Reverse
"\e[30m".."\e[37m"  # Foreground: Black..White
"\e[40m".."\e[47m"  # Background: Black..White
"\e[90m".."\e[97m"  # Bright foreground (256-color era)
"\e[38;5;${X}m" # 256-color foreground (X = 0-255)
"\e[48;5;${X}m" # 256-color background

# Cursor movement:
"\e[A"           # Up
"\e[B"           # Down
"\e[C"           # Right
"\e[D"           # Left
"\e[H"           # Home (top-left)
"\e[2J"          # Clear screen
"\e[K"           # Clear to end of line
"\e[s"           # Save cursor
"\e[u"           # Restore cursor
"\e[${r};${c}H"  # Position cursor at row r, col c

# OSC 8 hyperlinks (SSH/modern terminal only):
"\e]8;;URL\a" . $text . "\e]8;;\a"
```

### 2d. Strip ANSI for length calculations

When computing visual width for padding or alignment:

```perl
# Inline (when you can't call strip_ansi):
(my $plain = $str) =~ s/\e\[[0-9;]*[A-Za-z]//g;
my $vis_len = length($plain);

# Using strip_ansi() from pb-framework (preferred in door modules):
my $vis_len = length(strip_ansi($colored_string));

# strip_ansi() definition (for reference):
sub strip_ansi {
    my $text = $_[0];
    $text =~ s/\e\[[0-9;]*[A-Za-z]//g;          # CSI sequences (colors, cursor)
    $text =~ s/\e\][^\e\a]*(?:\a|\e\\)//g;      # OSC sequences (hyperlinks, BEL or ST)
    $text =~ s/\e[^\[\]]//g;                     # Other ESC sequences
    return $text;
}
```

---

## 3. BOX DRAWING

### 3a. Framework boxchar() - for BBS/door modules

```perl
# In modules using pb-framework (all door games, pb-main, etc.):
my $h   = boxchar('horizontal');   # horizontal line
my $v   = boxchar('vertical');     # vertical line
my $tl  = boxchar('topleft');      # top-left corner
my $tr  = boxchar('topright');     # top-right corner
my $bl  = boxchar('bottomleft');   # bottom-left corner
my $br  = boxchar('bottomright');  # bottom-right corner
my $td  = boxchar('tdown');        # T pointing down
my $tu  = boxchar('tup');          # T pointing up
my $tr2 = boxchar('tright');       # T pointing right
my $tl2 = boxchar('tleft');        # T pointing left
my $x   = boxchar('cross');        # cross / intersection
# Double-line (CP437 only; falls back to single for PETSCII):
my $dh  = boxchar('dhorizontal');  # double horizontal line
my $dv  = boxchar('dvertical');    # double vertical line
```

boxchar() dispatches based on `$config{'terminal_width'}`:
- 40 columns -> PETSCII (C64)
- otherwise -> CP437

For SSH users, pb-render's `_box()` returns UTF-8 box-drawing chars (U+2500 range).
In regular door game code, `boxchar()` is sufficient and works on all clients.

### 3b. Drawing a standard box

```perl
my $h = boxchar('horizontal');
my $W = 40;  # inner width (characters between corners)
writeline($config{'linecolor'} .
    boxchar('topleft') . ($h x $W) . boxchar('topright') . $RST, 1);
writeline($config{'linecolor'} .
    boxchar('vertical') . $RST .
    " content here " .
    $config{'linecolor'} . boxchar('vertical') . $RST, 1);
writeline($config{'linecolor'} .
    boxchar('bottomleft') . ($h x $W) . boxchar('bottomright') . $RST, 1);
```

### 3c. Drawing a table with column separators

```perl
my ($h, $v) = (boxchar('horizontal'), boxchar('vertical'));
my ($tl, $tr, $bl, $br) = map { boxchar($_) } qw(topleft topright bottomleft bottomright);
my ($td, $tu, $tr2, $tl2, $x) = map { boxchar($_) } qw(tdown tup tright tleft cross);
my $lc = $config{'linecolor'};

sub _boxrow_top {
    my @w = @_;
    return $lc . $tl . join($td, map { $h x $_ } @w) . $tr . $RST;
}
sub _boxrow_sep {
    my @w = @_;
    return $lc . $tr2 . join($x, map { $h x $_ } @w) . $tl2 . $RST;
}
sub _boxrow_bot {
    my @w = @_;
    return $lc . $bl . join($tu, map { $h x $_ } @w) . $br . $RST;
}
sub _boxrow_data {
    my ($cells_ref) = @_;  # arrayref of [color, plain_text, col_width]
    # col_width = INNER field width (the N in sprintf "%-Ns").
    # Each rendered cell visually occupies col_width chars (no auto margin).
    # _boxrow_top/sep/bot use the SAME col_width values for their H-char runs.
    # The border character V sits immediately adjacent to the content - no
    # automatic padding is added. If you want 1-char margins, add 2 to width
    # and pad the text yourself, OR add spaces to the text string.
    my $line = $lc . $v . $RST;
    for my $c (@$cells_ref) {
        my ($col, $txt, $w) = @$c;
        my $padded = sprintf("%-${w}s", substr($txt, 0, $w));
        $line .= $col . $padded . $RST . $lc . $v . $RST;
    }
    return $line;
}

# Usage:
writeline(_boxrow_top(18, 7, 6), 1);    # top border: col widths 18, 7, 6
writeline(_boxrow_data([               # header row
    [$config{'datacolor'}, "Name",  18],
    [$config{'datacolor'}, "Score",  7],
    [$config{'datacolor'}, "Wins",   6],
]), 1);
writeline(_boxrow_sep(18, 7, 6), 1);    # separator
# ... data rows ...
writeline(_boxrow_bot(18, 7, 6), 1);    # bottom border

# ANTIPATTERN - passing $w+2 while format already adds spaces:
# my ($NW) = (16);
# writeline(_boxrow_top($NW+2, ...), 1);  # WRONG: adds 4 more H chars per col
# writeline(_boxrow_data([{ ..., width => $NW+2 }]), 1);  # WRONG: over-wide cells
# Always pass the SAME width to _boxrow_top/_sep/_bot/_boxrow_data.
```

---

## 4. TEXT LAYOUT PATTERNS

### 4a. Standard menu item format

```perl
# Key ... Description  (canonical PhotonBBS style)
writeline("  " .
    $config{'promptcolor'} . "A" .
    $config{'themecolor'}  . " ... " .
    $config{'usercolor'}   . "Action description" .
    $RST, 1);

# With sub-description in systemcolor:
writeline("  " .
    $config{'promptcolor'} . "G" .
    $config{'themecolor'}  . " ... " .
    $config{'usercolor'}   . "Play a Game" .
    $config{'systemcolor'} . " (3 players)" .
    $RST, 1);
```

### 4b. Standard screen header pattern

```perl
writeline($CLR, 0);  # clear screen
writeline("", 1);
writeline($config{'themecolor'} . "          G A M E   T I T L E" . $RST, 1);
writeline($config{'linecolor'}  . "       Optional subtitle or tagline" . $RST, 1);
writeline("", 1);
```

### 4c. Label: Value pairs

```perl
# System label: user value
writeline($config{'systemcolor'} . "  Balance: " .
          $config{'usercolor'}   . door_money($balance) . $RST, 1);

# Two values on one line:
writeline($config{'systemcolor'} . " HP: " .
          $config{'datacolor'}   . "$hp/$max_hp" .
          $config{'systemcolor'} . "  MP: " .
          $config{'datacolor'}   . "$mp/$max_mp" . $RST, 1);
```

### 4d. Columnar data with sprintf

```perl
# Use sprintf for fixed-width columns, but ONLY on plain (non-ANSI) strings.
# Then colorize AFTER padding.

# Who's online pattern (from pb-framework whosonline):
printf("%-4s %-16s %-10s %-30s\n", $node, $username, $proto, $location);

# Score table with color (from pb-doorlib door_show_scores):
writeline(sprintf("  %s%-12s%s %s%5d%s  Wins: %s%d%s",
    $config{'usercolor'}, $name, $RST,
    $config{'datacolor'}, $score, $RST,
    $config{'datacolor'}, $wins, $RST), 1);

# Two-column layout (canonical pattern from pb-main):
my $col_width = 38;
my $left_str = "  " . $config{'datacolor'} . $key . $config{'themecolor'} .
               " ... " . $config{'usercolor'} . $desc . $RST;
# key and desc are plain text (no ANSI), so length() is safe:
my $left_visible = 2 + length($key) + 5 + length($desc);
my $padding = $col_width - $left_visible;
$padding = 1 if $padding < 1;
writeline($left_str . (" " x $padding) . $right_str, 1);

# CRITICAL: if any component is variable-length (item name, score, etc.),
# the colored string MUST pad it to the same fixed width as the plain version.
# Otherwise the two versions have different visible widths -> misalignment.
#
# WRONG - colored name omits %-18s padding:
#   my $plain   = sprintf("  %s ... %-18s x%d", $key, $name, $qty);
#   my $colored = "  " . $pk . $key . $RST . " ... " . $name . "  x$qty" . $RST;
#   # $plain always 30 chars; $colored varies 22-30 -> right column drifts
#
# CORRECT - both use the same fixed width for variable fields:
#   my $name_padded = sprintf("%-18s", $name);       # always 18 chars
#   my $plain   = "  $key ... $name_padded x$qty";   # always 30 chars
#   my $colored = "  " . $pk . $key . $RST . " ... " . $name_padded . "  x$qty" . $RST;
#
# ALSO CRITICAL: sprintf("%-Ns", $str) does NOT truncate strings longer than N.
# A string longer than N overflows and shifts the right column.
# Always use substr() before sprintf to enforce the maximum width:
#
#   my $desc_padded = sprintf("%-${DESC_W}s", substr($desc, 0, $DESC_W));
#   # Guaranteed to always be exactly DESC_W visible chars
```

### 4e. 24-line terminal budget

The critical constraint for door games:

```
Line 1:   Title line
Line 2:   Horizontal separator
Lines 3-N: Board / game area
...
Line 22:  Status / info line
Line 23:  Separator
Line 24:  Prompt (NO trailing newline)
```

From pb-door-1000miles (4-player 2-column board example):
- 1 title + 3 separators + 6 player rows + 1 hand header + 4 hand rows + 1 blank + 1 deck status = 17 lines
- Remaining 7 = 1 blank + (num_players-1) action log entries + 1 draw + 1 blank + 1 prompt

**Rule:** Player/content blocks must be FIXED height. Put optional data on the
name line as `[tag]` suffixes, NEVER as optional rows. Variable-height blocks
overflow when optional data appears.

**Final line rule:** The input prompt must have NO trailing newline. If commands
and the prompt are on separate lines, the prompt must be last and must not print
a newline before getline()/waitkey():

```perl
# WRONG - prompt pushed to line 25:
writeline("  Q ... Quit    E ... Equip", 1);  # ends with \n
writeline("  Choice: ", 0);                   # another line (now row 25)

# RIGHT - commands and prompt on same final line:
writeline("  Q ... Quit    E ... Equip    Choice: ", 0);  # no trailing \n
```

### 4f. Side-panel layout (The Crypt pattern)

For tile-based games needing a side panel:

```perl
my $VIEW_W  = 40;  # map viewport width (visual chars per row)
my $PANEL_X = 42;  # panel column (VIEW_W + 2-char gap)

for my $row (0 .. $VIEW_H - 1) {
    my $map_line   = build_map_row($row);   # exactly $VIEW_W visual chars (strip ANSI to verify)
    my $panel_line = $panel[$row] // "";
    writeline($map_line . "  " . $panel_line, 1);
}
```

The map viewport must produce exactly `$VIEW_W` visual characters per row
(after stripping ANSI). Strip and measure during development to verify alignment.

---

## 5. CP437 SPECIAL CHARACTERS

```perl
# Card suit symbols (used in door_draw_cards):
chr(3)   # Heart
chr(4)   # Diamond
chr(5)   # Club
chr(6)   # Spade

# Block/shade characters (used in pb-bigtext _bt_char):
chr(219) # Full block
chr(220) # Lower half block
chr(221) # Left half block
chr(222) # Right half block
chr(223) # Upper half block
chr(176) # Light shade
chr(177) # Medium shade
chr(178) # Dark shade

# Other useful characters:
chr(254) # Small filled square (bullet)
chr(250) # Middle dot
chr(249) # Small bullet
chr(26)  # Right arrow
chr(27)  # Left arrow (CAUTION: same byte as ESC - avoid in ANSI contexts)
chr(24)  # Up arrow
chr(25)  # Down arrow
chr(7)   # Bell (BEL)
```

**CRITICAL:** For SSH/UTF-8 connections, CP437 chars above 127 require special
handling. pb-render and pb-bigtext handle this automatically. In regular door
game code using `boxchar()`, the framework handles CP437 vs PETSCII dispatch.
Do NOT output raw CP437 > 127 in code that runs for SSH users.

---

## 6. BIG TEXT ENGINE (pb-bigtext)

### 6a. API

```perl
bigtext($text, %opts)         # Returns arrayref of rendered lines
bigtext_write($text, %opts)   # Render + writeline each line
bigtext_string($text, %opts)  # Returns single string (lines joined by \n)
bigtext_width($text, %opts)   # Returns visual width in columns
bigtext_fits($text, %opts)    # Returns 1 if text fits in terminal width
bigtext_fonts()               # Returns list of available font names
bigtext_styles()              # Returns list of available style names
bigtext_chars($font)          # Returns chars supported by a font
```

### 6b. Fonts

| Font | Height | Characters | Notes |
|------|--------|------------|-------|
| `block` | 5 rows | A-Z 0-9 + punct | CP437 block chars, ANSI color |
| `miniwi` | 3-4 rows | A-Z 0-9 | Unicode quadrant blocks |
| `bloody` | 10 rows | A-Z | Elaborate shade/block chars |
| `photon` | 7 rows | A-Z 0-9 + some punct | Unicode block chars |
| `dosrebel` | 7 rows | A-Z 0-9 | CP437 shade chars, retro DOS |
| `doom` | 6 rows | A-Z 0-9 | CP437 multi-shade classic |

### 6c. Options

```perl
bigtext_write("HELLO",
    font  => 'block',             # Font name (default: 'block')
    color => $config{'themecolor'}, # ANSI color prefix
    center => 1,                  # Center in terminal_width (default: 0)
    style  => 'block',            # 'block', 'shade', 'outline' (font-dependent)
    width  => 80,                 # Override terminal width for centering
);
```

### 6d. SSH compatibility note

The `photon` and `miniwi` fonts use Unicode block characters (`\x{2588}` etc.)
which require `use utf8` at the top of any file with Unicode string literals.
CP437 fonts use `_bt_char()` which dispatches based on terminal width.

---

## 7. MARKDOWN RENDERING (pb-render)

pb-render is for rendering `.md` documentation files ONLY. It is NOT for BBS UI
elements (menus, game screens, score tables, who-lists).

```perl
# CORRECT uses:
render_markdown($file_content)         # In readfile() for .md files automatically
render_table(@rows, header => 1)       # For help/documentation tables only
render_header("Section Title", 2)      # For doc section headers only

# WRONG uses (NEVER DO THESE):
render_table(...) for game score boards  # Use door_show_scores() instead
render_table(...) for who-is-online      # Use writeline() + sprintf instead
render_markdown(...) for game menus      # Use writeline() patterns instead
```

---

## 8. VISUAL ALIGNMENT - THE ANSI WIDTH PROBLEM IN PERL

### 8a. The problem

```perl
my $colored = $config{'usercolor'} . "Alice" . $RST;
printf("%-20s", $colored);  # WRONG: pads by byte length, not visual chars
# ANSI codes add ~10 bytes; result is 10 chars shorter than expected
```

### 8b. The solution patterns

**Pattern 1 - Pad plain, then colorize (preferred):**
```perl
my $name       = "Alice";
my $padded     = sprintf("%-20s", $name);   # pad plain text
my $colorized  = $config{'usercolor'} . $padded . $RST;  # then colorize
```

**Pattern 2 - Colorize first, strip to measure, add padding:**
```perl
my $colored    = build_colored_cell($data);
my $vis_len    = length(strip_ansi($colored));
my $pad        = $col_width - $vis_len;
$pad           = 0 if $pad < 0;
my $cell       = $colored . (" " x $pad);  # now exactly $col_width wide
```

**Pattern 3 - Track visible width at build time (multi-column boards):**
```perl
# Build each cell as [colored_string, visible_char_count] pair
my $plain_vis  = "  " . $marker . " " . $name . $tag;  # plain version
my $colored    = "  " . $marker . " " . $namecolor . $name . $RST . $tag;
my $vis_len    = length($plain_vis);   # safe: plain has no ANSI

# Then pad using the tracked length:
my $pad = $col_width - $vis_len;
$pad = 0 if $pad < 0;
$line .= $colored . (" " x $pad);
```

### 8c. Perl's byte/character model

PhotonBBS runs with `binmode(STDOUT, ':raw')` in photonbbs-client:

| Value | is_utf8 flag | Bytes on wire | Notes |
|-------|-------------|---------------|-------|
| `chr(196)` | no | 1 byte (0xC4) | CP437 horizontal box, safe for telnet |
| `chr(219)` | no | 1 byte (0xDB) | CP437 full block, safe for telnet |
| `chr(0x2588)` | yes | 3 bytes (E2 96 88) | Unicode full block, SSH only |
| `"\e[34m"` | no | 5 bytes | ANSI color code |

`length()` always counts characters, not bytes. For ASCII and CP437 chars (0-255),
one character = one byte = one terminal column. For ANSI-colored strings:

```perl
# CORRECT - strip ANSI, measure, then pad plain, then colorize:
my $plain_name = substr($name, 0, 20);          # truncate plain text
my $padded     = sprintf("%-20s", $plain_name); # pad plain text
writeline($config{'usercolor'} . $padded . $RST, 1);

# WRONG - sprintf on ANSI-colored string:
writeline(sprintf("%-20s", $config{'usercolor'} . $name . $RST), 1);
# %-20s pads by byte length including escape codes -> result is too short!
```

### 8d. The off-by-two trap with bracket characters

```perl
# WRONG - bracket chars outside the padding measurement:
my $bar    = hp_bar($hp, $max_hp, 20);  # returns "[####----]" with ANSI
my $vis    = length(strip_ansi($bar));  # measures 10 (brackets included)
# If you concatenate brackets AFTER measuring, alignment breaks.

# RIGHT - include ALL visual characters in the measurement:
my $plain_bar = "[" . ("#" x $filled) . ("-" x $empty) . "]";
my $vis_len   = length($plain_bar) + length(" $hp/$max_hp");  # manual count
my $colored   = hp_color($pct) . $plain_bar . $RST . " $hp/$max_hp";
# Now pad using $vis_len, not length($colored)
```

---

## 9. PB-DOORLIB GRAPHICS

### 9a. Cards - door_draw_cards(\@cards, $base_color, $label)

```perl
# @cards = arrayref of 2-char strings: rank + suit letter
# Valid ranks: 2-9, T (or 10), J, Q, K, A
# Valid suits: H (hearts), D (diamonds), C (clubs), S (spades)
# Use '?' for face-down / unknown card
door_draw_cards(["AH", "10D", "KS", "?"],
    $config{'linecolor'}, "Dealer:");
```

Renders 5 rows tall per card using boxchar() for borders. Suits colored:
- H, D -> errorcolor (red)
- C, S -> datacolor
- '?' (face-down) -> linecolor

### 9b. Dice - door_draw_dice(\@values, \@kept, $color)

```perl
door_draw_dice([3, 4, 1], [0, 1, 0], $config{'linecolor'});
# kept dice shown in usercolor instead of base_color
# Labels underneath: die number or "KEPT"
```

### 9c. Slot machine - door_draw_slots(\@reels, $winning)

```perl
door_draw_slots(["Cherry", "Bell", "7"], 1);
# winning=1: reels shown in usercolor; 0: datacolor
```

---

## 10. ACTION LOG PATTERN

For multiplayer door games where AIs play between human turns:

```perl
# Rules from pb-door-1000miles:
# 1) Don't log human's own actions (they see them happen)
# 2) Snapshot and clear at start of each human turn:
my @pending_log = @action_log;   # what happened since last human turn
@action_log = ();                # reset for next interval

# 3) Show pending_log before the new board/prompt
# 4) Limit display to (num_players - 1) entries max
# 5) AIs play silently - no board redraw between AI turns;
#    show everything accumulated on the next human board redraw

# Example display:
my $max_log = $num_players - 1;
my @show = splice(@pending_log, -$max_log);  # take latest N
for my $event (@show) {
    writeline("  " . $config{'systemcolor'} . $event . $RST, 1);
}
```

---

## 11. COMMON MISTAKES

### 11a. sprintf on ANSI-colored strings

```perl
# WRONG - pads byte length not visual length:
sprintf("%-20s", $config{'usercolor'} . $name . $RST)

# RIGHT - pad first, then colorize:
sprintf("%s%-20s%s", $config{'usercolor'}, $name, $RST)
```

### 11b. CP437 box chars for SSH users

```perl
# WRONG - raw chr() only works on CP437/telnet:
my $line = chr(196) x 40;

# RIGHT - boxchar() returns the correct char for the connection type:
my $line = boxchar('horizontal') x 40;
```

### 11c. Hardcoded terminal width

```perl
# WRONG:
my $sep = "-" x 78;

# RIGHT:
my $w = $config{'terminal_width'} || 80;
my $sep = "-" x ($w - 2);
```

### 11d. Variable-height display blocks

```perl
# WRONG - optional rows cause height changes:
writeline($name_line, 1);
writeline($buff_line, 1) if @buffs;   # height varies!

# RIGHT - fixed height, put optional data inline:
my $buff_tag = @buffs ? " [" . join(",", @buffs) . "]" : "";
writeline($name_line . $buff_tag, 1);   # always 1 line
```

### 11e. Unicode in Perl without `use utf8`

```perl
# WRONG - Unicode string literals without utf8 pragma:
my $block = "\x{2588}";  # may warn or mangle without 'use utf8'

# RIGHT - use utf8 at the top of any file with Unicode literals:
use utf8;
my $block = "\x{2588}";  # correctly handled as Unicode codepoints

# OR use explicit escape sequences (no pragma needed):
my $block = "\x{2588}\x{2584}";
```

### 11e2. `use open ':encoding(UTF-8)'` breaks CP437/telnet output

This is a critical mistake when writing door games or test mockups.

```perl
# WRONG - use open encodes ALL stdout as UTF-8, destroying CP437 bytes:
use open ':std', ':encoding(UTF-8)';

# If boxchar() returns chr(196) (\xC4 = CP437 ─), Perl will encode it
# as UTF-8 sequence C3 84 (Ä) -> the telnet client sees garbage.
# This is why telnet users see: ÎÃ¶ÃÎÃ¶ÃÎÃ¶Ã instead of ─────────

# RIGHT for CP437/telnet: raw binary STDOUT, no encoding layer:
binmode(STDOUT, ':raw');  # emit chr(196) as single byte 0xC4

# RIGHT for SSH/UTF-8: UTF-8 encoding layer:
binmode(STDOUT, ':encoding(UTF-8)');  # emit \x{2500} as E2 94 80

# In door games, boxchar() handles this automatically - it returns
# the right bytes for the connection type. Never add use open.

# Pattern for mockup scripts with protocol flag:
my $UTF8_MODE = grep { $_ eq '--utf8' } @ARGV;
@ARGV = grep { $_ ne '--utf8' } @ARGV;
if ($UTF8_MODE) {
    binmode(STDOUT, ':encoding(UTF-8)');
} else {
    binmode(STDOUT, ':raw');
}
my %BOXCHARS = $UTF8_MODE
    ? (horizontal => "\x{2500}", vertical => "\x{2502}", topleft => "\x{250C}", ...)
    : (horizontal => chr(196),   vertical => chr(179),   topleft => chr(218),  ...);
```

### 11f. Forgetting to reset color at end of colored output

```perl
# WRONG - color bleeds into next line:
writeline($config{'errorcolor'} . "Warning!", 1);

# RIGHT - always reset:
writeline($config{'errorcolor'} . "Warning!" . $RST, 1);
```

### 11g. Prompt on row 25 after filling rows 1-24

```perl
# WRONG - prompt pushed off-screen:
writeline("  Q ... Quit    E ... Equip", 1);  # ends with \n
writeline("  Choice: ", 0);                   # row 25!

# RIGHT - commands and prompt on the same final line:
writeline("  Q ... Quit    E ... Equip    Choice: ", 0);  # no trailing \n
```

### 11h. sprintf does not truncate - always use substr before padding

```perl
# WRONG - overflows if string is longer than N:
my $label = sprintf("%-20s", $description);
# If $description is 26 chars, label is 26 chars, not 20 -> right column drifts

# RIGHT - truncate first, then pad:
my $label = sprintf("%-20s", substr($description, 0, 20));
# Always exactly 20 visible chars, regardless of input length

# This is critical in any two-column layout where $desc_width anchors the
# right column. One overflowing left item breaks all subsequent alignment.
```

---

## 12. ANSI DETECTION AND CAPABILITIES

```perl
# ANSI support (set during login negotiation):
$info{'ansi'}   # '1' = ANSI capable, '0' = dumb terminal

# Protocol:
$info{'proto'}  # 'TELNET' or 'SSH'

# Terminal dimensions:
$config{'terminal_width'}   # 40 or 80 (or larger for SSH)
$config{'terminal_height'}  # usually 24

# Conditional ANSI output:
if ($info{'ansi'} eq '1') {
    writeline($config{'themecolor'} . "Banner" . $RST, 1);  # Full color
} else {
    writeline("Banner", 1);  # Plain text fallback
}

# SSH-specific features (Unicode, OSC 8 links, bigtext photon/miniwi fonts):
if ($info{'proto'} eq 'SSH') {
    # Use UTF-8 box chars, hyperlinks, Unicode bigtext fonts
} else {
    # Stick to CP437
}

# PETSCII/C64 mode:
if ($config{'terminal_width'} == 40) {
    # Use PETSCII-safe characters only
    # boxchar() handles this automatically
}
```

---

## 13. WORKING EXAMPLES

### 13a. Game title screen

```perl
sub show_title {
    my ($game_name, $tagline, $balance) = @_;
    writeline($CLR, 0);
    writeline("", 1);
    writeline($config{'themecolor'} . "          " .
        join(" ", split(//, uc($game_name))) . $RST, 1);
    writeline($config{'linecolor'}  . "       $tagline" . $RST, 1);
    writeline("", 1);
    writeline($config{'systemcolor'} . "  Your balance: " .
              $config{'usercolor'}   . door_money($balance) . $RST, 1);
    writeline("", 1);
}
```

### 13b. Fixed-width score table

```perl
sub show_score_table {
    my @players = @_;  # ({name, score, wins}, ...)
    my $h = boxchar('horizontal');
    my $v = boxchar('vertical');
    my ($tl, $tr, $bl, $br) = map { boxchar($_) }
        qw(topleft topright bottomleft bottomright);
    my ($td, $tu, $tr2, $tl2, $x) = map { boxchar($_) }
        qw(tdown tup tright tleft cross);
    my $lc = $config{'linecolor'};
    my ($NW, $SW, $WW) = (16, 8, 6);  # col widths (inner)

    writeline($lc . $tl . ($h x ($NW+2)) . $td .
              ($h x ($SW+2)) . $td .
              ($h x ($WW+2)) . $tr . $RST, 1);
    writeline($lc . $v . $RST .
        $config{'datacolor'} . sprintf(" %-${NW}s ", "Name") . $RST .
        $lc . $v . $RST .
        $config{'datacolor'} . sprintf(" %-${SW}s ", "Score") . $RST .
        $lc . $v . $RST .
        $config{'datacolor'} . sprintf(" %-${WW}s ", "Wins") . $RST .
        $lc . $v . $RST, 1);
    writeline($lc . $tr2 . ($h x ($NW+2)) . $x .
              ($h x ($SW+2)) . $x .
              ($h x ($WW+2)) . $tl2 . $RST, 1);
    for my $p (@players) {
        writeline($lc . $v . $RST .
            $config{'usercolor'} . sprintf(" %-${NW}s ", substr($p->{name}, 0, $NW)) . $RST .
            $lc . $v . $RST .
            $config{'datacolor'} . sprintf(" %-${SW}s ", $p->{score}) . $RST .
            $lc . $v . $RST .
            $config{'datacolor'} . sprintf(" %-${WW}s ", $p->{wins}) . $RST .
            $lc . $v . $RST, 1);
    }
    writeline($lc . $bl . ($h x ($NW+2)) . $tu .
              ($h x ($SW+2)) . $tu .
              ($h x ($WW+2)) . $br . $RST, 1);
}
```

### 13c. HP/progress bar

The canonical PhotonBBS pattern uses ASCII `#` and `-` - works on ALL clients:

```perl
sub hp_bar {
    my ($current, $max, $width) = @_;
    $width //= 20;
    $max = 1 if $max <= 0;
    my $pct = ($current / $max);
    $pct = 0 if $pct < 0;
    $pct = 1 if $pct > 1;
    my $filled = int($pct * $width);
    my $empty  = $width - $filled;
    my $clr    = ($pct > 0.5)  ? $config{'usercolor'}   :
                 ($pct > 0.25) ? $config{'promptcolor'}  :
                                 $config{'errorcolor'};
    return $clr . ("#" x $filled) . $config{'linecolor'} . ("-" x $empty) . $RST .
           " " . $config{'datacolor'} . "$current/$max" . $RST;
}

# Usage:
writeline($config{'systemcolor'} . "HP: " . hp_bar($hp, $max_hp, 15), 1);
```

### 13d. Centered text

```perl
sub center_line {
    my ($text, $color, $width) = @_;
    $width //= $config{'terminal_width'} || 80;
    # strip_ansi() from pb-framework handles CSI, OSC, and bare ESC sequences
    my $plain = strip_ansi($text);
    my $pad   = int(($width - length($plain)) / 2);
    $pad = 0 if $pad < 0;
    writeline((" " x $pad) . ($color // "") . $text . ($color ? $RST : ""), 1);
}
```

---

## 14. COLOR USAGE CONVENTIONS

| Element | Color Variable |
|---------|---------------|
| Game/screen title | `themecolor` |
| Section headers | `themecolor` |
| Separator lines / borders | `linecolor` |
| Label text ("Balance:", "HP:") | `systemcolor` |
| Player names | `usercolor` |
| Win/success messages | `usercolor` or `promptcolor` |
| Monetary values, scores | `datacolor` |
| Command keys (A, B, Q...) | `promptcolor` |
| Error/danger messages | `errorcolor` |
| HP bar high (>50%) | `usercolor` |
| HP bar medium (25-50%) | `promptcolor` |
| HP bar low (<25%) | `errorcolor` |
| News/log messages | `systemcolor` |
| Online player list | `usercolor` |
| Face-down / unknown | `linecolor` |
| Currently selected / kept | `usercolor` |

---

## 15. CHECKLIST BEFORE WRITING A DISPLAY FUNCTION

- [ ] Does it use `boxchar()` (not raw `chr()`) for box chars?
- [ ] Are all ANSI strings terminated with `$RST`?
- [ ] Is `sprintf` only applied to plain (non-ANSI) strings?
- [ ] Is the total line count <= 24 (for all possible states)?
- [ ] Are player/content blocks fixed height?
- [ ] Is `$config{'terminal_width'}` used instead of hardcoded 80?
- [ ] Are SSH/telnet differences handled (via boxchar / _box / _bt_char)?
- [ ] Does dumb-terminal mode (`$info{'ansi'} ne '1'`) fall back gracefully?
- [ ] Is any Unicode requiring `use utf8` pragma in the file?
- [ ] Does the action log limit to (num_players - 1) entries?
- [ ] Does the prompt line end without a trailing newline?
- [ ] Verified actual column widths? Strip ANSI and measure each row to confirm.
