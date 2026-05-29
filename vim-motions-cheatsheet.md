# Vim Motions Cheatsheet

## Mode Switching

| Key | Action |
|-----|--------|
| `i` | Insert before cursor |
| `I` | Insert at start of line |
| `a` | Append after cursor |
| `A` | Append at end of line |
| `o` | Open line below |
| `O` | Open line above |
| `v` | Visual mode |
| `V` | Visual line mode |
| `Ctrl-v` | Visual block mode |
| `Esc` | Normal mode |
| `Ctrl-[` | Normal mode (alt) |

## Movement

### Basic

| Key | Action |
|-----|--------|
| `h` / `j` / `k` / `l` | Left / Down / Up / Right |
| `w` | Next word start |
| `W` | Next WORD start |
| `e` | Next word end |
| `E` | Next WORD end |
| `b` | Previous word start |
| `B` | Previous WORD start |
| `0` | Start of line |
| `^` | First non-blank char |
| `$` | End of line |
| `gg` | First line |
| `G` | Last line |
| `{number}G` | Go to line number |
| `{number}gg` | Go to line number |

### Find / Search

| Key | Action |
|-----|--------|
| `f{char}` | Next char on line |
| `F{char}` | Previous char on line |
| `t{char}` | Before next char |
| `T{char}` | Before previous char |
| `;` | Repeat f/F/t/T |
| `,` | Repeat f/F/t/T reverse |
| `/{pattern}` | Search forward |
| `?{pattern}` | Search backward |
| `n` | Next search match |
| `N` | Previous search match |
| `*` | Search word under cursor |
| `#` | Search word backward |

### Text Objects (with operator or visual)

| Key | Action |
|-----|--------|
| `iw` | Inner word |
| `aw` | A word (with space) |
| `iW` | Inner WORD |
| `aW` | A WORD |
| `i"` | Inner double quotes |
| `a"` | A double quotes |
| `i'` | Inner single quotes |
| `a'` | A single quotes |
| `i(` | Inner parentheses |
| `a(` | A parentheses |
| `i[` | Inner brackets |
| `a[` | A brackets |
| `i{` | Inner braces |
| `a{` | A braces |
| `i<` | Inner angle brackets |
| `a<` | A angle brackets |
| `it` | Inner HTML tag |
| `at` | A HTML tag |

### Scope

| Key | Action |
|-----|--------|
| `%` | Matching bracket |
| `{` | Previous paragraph |
| `}` | Next paragraph |

## Editing

### Delete

| Key | Action |
|-----|--------|
| `x` | Delete char |
| `X` | Delete char before |
| `dd` | Delete line |
| `D` | Delete to end of line |
| `dw` | Delete word |
| `d$` | Delete to end of line |
| `d0` | Delete to start of line |
| `dG` | Delete to end of file |
| `dgg` | Delete to start of file |
| `d{motion}` | Delete motion range |
| `{number}dd` | Delete N lines |

### Change

| Key | Action |
|-----|--------|
| `c` | Change (enters insert) |
| `cc` | Change line |
| `C` | Change to end of line |
| `cw` | Change word |
| `cb` | Change back word |
| `c$` | Change to end of line |
| `ciw` | Change inner word |
| `ci"` | Change inside quotes |
| `ci(` | Change inside parens |
| `cit` | Change inside tag |
| `ct{char}` | Change to char |
| `{number}cc` | Change N lines |

### Yank / Paste

| Key | Action |
|-----|--------|
| `y` | Yank (copy) |
| `yy` | Yank line |
| `Y` | Yank line (alt) |
| `yw` | Yank word |
| `y$` | Yank to end of line |
| `yi"` | Yank inside quotes |
| `yi(` | Yank inside parens |
| `p` | Paste after |
| `P` | Paste before |

### Replace

| Key | Action |
|-----|--------|
| `r{char}` | Replace char |
| `R` | Replace mode |
| `~` | Toggle case |
| `gU{motion}` | Uppercase |
| `gu{motion}` | Lowercase |

### Undo / Redo

| Key | Action |
|-----|--------|
| `u` | Undo |
| `Ctrl-r` | Redo |
| `.` | Repeat last change |

## Windows

| Key | Action |
|-----|--------|
| `Ctrl-w s` | Split horizontal |
| `Ctrl-w v` | Split vertical |
| `Ctrl-w w` | Next window |
| `Ctrl-w h` | Move left |
| `Ctrl-w j` | Move down |
| `Ctrl-w k` | Move up |
| `Ctrl-w l` | Move right |
| `Ctrl-w H` | Move window left |
| `Ctrl-w J` | Move window down |
| `Ctrl-w K` | Move window up |
| `Ctrl-w L` | Move window right |
| `Ctrl-w =` | Equal size |
| `Ctrl-w _` | Max height |
| `Ctrl-w \|` | Max width |
| `Ctrl-w q` | Close window |
| `Ctrl-w o` | Close all others |
| `Ctrl-w T` | Move to new tab |

## Buffers / Tabs

| Key | Action |
|-----|--------|
| `:bn` | Next buffer |
| `:bp` | Previous buffer |
| `:bd` | Close buffer |
| `:e {file}` | Open file |
| `:tabnew` | New tab |
| `gt` | Next tab |
| `gT` | Previous tab |

## Marks

| Key | Action |
|-----|--------|
| `m{a-z}` | Set local mark |
| `m{A-Z}` | Set global mark |
| `'{mark}` | Go to mark (line) |
| `` `{mark}` `` | Go to mark (exact) |
| `''` | Jump to last position |

## Jumps

| Key | Action |
|-----|--------|
| `Ctrl-o` | Jump list back |
| `Ctrl-i` | Jump list forward |
| `:marks` | Show all marks |

## Registers

| Key | Action |
|-----|--------|
| `"{reg}` | Select register |
| `:reg` | Show all registers |
| `"+y` | Yank to system clipboard |
| `"+p` | Paste from system clipboard |
| `""` | Default register |
| `"0` | Yank register |

## Folding

| Key | Action |
|-----|--------|
| `za` | Toggle fold |
| `zo` | Open fold |
| `zc` | Close fold |
| `zR` | Open all folds |
| `zM` | Close all folds |
| `zj` | Next fold |
| `zk` | Previous fold |

## Misc

| Key | Action |
|-----|--------|
| `:` | Command mode |
| `.` | Repeat last change |
| `&` | Repeat last :s |
| `@{reg}` | Execute register macro |
| `q{reg}` | Record macro |
| `q` | Stop recording |
| `Ctrl-a` | Increment number |
| `Ctrl-x` | Decrement number |
| `Ctrl-r =` | Expression register |
| `ga` | Show ASCII code |
| `g8` | Show UTF-8 bytes |

## Quick Reference: Common Combos

| Combo | Action |
|-------|--------|
| `ciw` | Change inner word |
| `di"` | Delete inside quotes |
| `ya(` | Yank around parens |
| `dt{char}` | Delete to char |
| `ct{char}` | Change to char |
| `df{char}` | Delete through char |
| `cf{char}` | Change through char |
| `ggVG` | Select all |
| `ggdG` | Delete all |
| `ci{` | Change inside braces |
| `dit` | Change inside tag |
| `da"` | Delete around quotes |
