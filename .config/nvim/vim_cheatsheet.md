# Vim Cheatsheet
---
`something` Command

`<x>` No literal entry

`i/n/v/...` Mode. Default is normal

---


**Movement (`<d>` field)**
- `hjkl`: Move 1 char left, down, up, right.
- `<n><d>`: Move 'n' lines in 'd' direction.
- `w`: Move to the beginning of the next word.
- `b`: Move to the beginning of the previous word.
- `_`: Move to the start of the line.
- `$`: Move to the end of the line.
- `0`: Move to the first char of the line.
- `f<char>`: Jump forward to 'char'.
- `t<char>`: Jump to char before 'char'.
- `,;`: Move to the previous and next char in jump.
- `F<char>`: Jump backward to 'char'.
- `t<char>`: Jump to char before 'char'.
- `{}`: Jump to the previous and next paragraph.
- `C-d`: Jump one screen down.
- `C-u`: Jump one screen up.
- `gg`: Jump to the top.
- `G`: Jump to the bottom.
- `:<n>`: Jump to line 'n'.
- `%`: Move to the matching symbol
- `n vi<c>`: Select between <c>.

**Copy, Paste, Delete**
- `d`: Delete.
- `dd`: Delete line.
- `d<n><d>`: Delete 'n' in direction 'd'.
- `db`: Delete backward.
- `y`: Copy.
- `yy`: Copy line.
- `y<n><d>`: Copy 'n' in direction 'd'.
- `p`: Paste.
- `p<n>`: Paste 'n' times.
- `x <leader>p`: Paste deleted content before the cursor in visual mode.
- `n,v <leader>y`: Copy to the clipboard in normal and visual modes.
- `n <leader>Y`: Copy from the current line to the end in normal mode.
- `n,v <leader>d`: Cut and delete content in normal and visual modes.

**Change Mode**
- `a`: Insert mode, after.
- `i`: Insert mode, before.
- `o`: Insert mode, new line.
- `O`: Insert mode, new line above.
- `v`: Visual mode.
- `V`: Visual lines mode.
- `C-v`: Visual block mode.
- `n A`: Insert mode at end of line.
- `n I`: Insert mode at start of line.


**Movement in Insert Mode**
- `Alt-I`: Jump to the start.
- `Alt-A`: Jump to the end.
- `Alt-o`: New line.
- `Alt-O`: New line above.

**Searching**
- `/<q>`: Search for 'q'.
- `enter`: Go to line.
- `n`: Jump to the next occurrence.
- `N`: Jump backward.
- `?<q>`: Inverted search for 'q'.
- `*`: Insert the word.

**Visual Mode Movement Mappings**
- `v J`: Move selection down.
- `v K`: Move selection up.
- `v <`: Indent selection up.
- `v >`: Unindent selection up.

**Navigation and Screen Adjustment Mappings**
- `n J`: Join current line with next.
- `n <C-d>`: Scroll down half a screen.
- `n <C-u>`: Scroll up half a screen.
- `n n`: Move down and adjust screen.
- `n N`: Move up and adjust screen.

**Other Commands**
- `n <leader>t`: Open a terminal (bspwm shortcut).
- `i <C-c>`: Exit insert mode.
- `n Q`: No operation.
- `n <leader>r`: Replace text.
- `n <leader>x`: Give execution permissions to the file.
- `n <leader>w`: Save all files.
- `n <leader>q`: Save all files and quit.

**Clipboard and Visual Mode Enhancements**
- `n <leader>p`: Paste deleted content before the cursor.
- `n <leader>y`: Copy to the clipboard.
- `n <leader>Y`: Copy from the current line to the end.
- `n <leader>d`: Cut and delete content.

**Harpoon Commands**
- `n <C-e>`: Toggle the Harpoon quick menu.
- `n <leader>a`: Add the current file to Harpoon marks.
- `n <leader>1`: Navigate to file in Harpoon slot 1.
- `n <leader>2`: Navigate to file in Harpoon slot 2.
- `n <leader>3`: Navigate to file in Harpoon slot 3.
- `n <leader>4`: Navigate to file in Harpoon slot 4.
- `n <leader>5`: Navigate to file in Harpoon slot 5.
- `n <leader>6`: Navigate to file in Harpoon slot 6.

**File Operations and Formatting**
- `n <leader>f`: Format the current file.
- `n <leader>x`: Give execution permissions to the file.

**Quickfix and Location List Navigation**
- `n <C-k>`: Move to the next quickfix entry.
- `n <C-j>`: Move to the previous quickfix entry.
- `n <leader>k`: Move to the next location list entry.
- `n <leader>j`: Move to the previous location list entry.
- `n <leader>xq`: Toggle quickfix.

**Search, Replace and Refactoring**
- `n <leader>r`: Replace text in the entire file.
- `<leader>ri`: Refactoring inline variable.

**UndoTree**
- `n <leader>u`: Toggle undotree.

**Telescope Commands**
- `n <leader>ff`: Open Telescope and find files.
- `n <leader>fb`: Open Telescope and list buffers.
- `n <leader>fD`: Open Telescope and list LSP implementations.
- `n <leader>fd`: Open Telescope and list LSP definitions.
- `n <leader>ft`: Open Telescope and list LSP type definitions.
- `n <leader>fa`: Open Telescope and list Treesitter queries.
- `n <leader>ps`: Grep file search.

**Git Integration**
- `n <leader>gs`: Execute `vim.cmd.Git`.

**Refactoring**
- `<leader>ri`: Refactor selected variable inline.
- `n <leader>p`: Git push.
- `n <leader>P`: Git pull with rebase.
- `n <leader>t`: Set the branch and push with tracking.

**Completion**
- `<C-p>`: Select Previous Item
- `<C-n>`: Select Next Item
- `<C-y>`: Confirm and Select
- `<C-Space>`: Complete

**Zen Mode**
- `<leader>zz`: Toggle zen-mode
- `<leader>zZ`: Toggle zen-mode (minimalist)
