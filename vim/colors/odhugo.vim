" Name:         od_hugo
" Author:
" Maintainer:
" Website:
" License:      Same as Vim
" Last Change:  2024 Aug 15

set background=dark

hi clear
let g:colors_name = 'od_hugo'

let s:t_Co = &t_Co

let s:bg = '#282c34'
let s:fg = '#abb2bf'
let s:black = '#1e2127'
let s:red = '#e06c75'
let s:green = '#98c379'
let s:yellow = '#d19abb'
let s:blue = '#61afef'
let s:magenta = '#c678dd'
let s:cyan = '#56b6c2'
let s:white = '#abb2bf'
let s:brblack = '#5c6370'
let s:NONE = 'NONE'
let s:underline = 'underline'
let s:bold = 'bold'
let s:reverse = 'reverse'
let s:undercurl = 'undercurl'

hi! link Terminal Normal
hi! link Boolean Constant
hi! link Character Constant
hi! link Conditional Repeat
hi! link Debug Special
hi! link Define PreProc
hi! link Delimiter Special
hi! link Exception Statement
hi! link Float Number
hi! link Include PreProc
hi! link Keyword Statement
hi! link Label Statement
hi! link Macro PreProc
hi! link Number Constant
hi! link PopupSelected PmenuSel
hi! link PreCondit PreProc
hi! link SpecialChar Special
hi! link SpecialComment Special
hi! link StatusLineTerm StatusLine
hi! link StatusLineTermNC StatusLineNC
hi! link StorageClass Type
hi! link String Constant
hi! link Structure Type
hi! link Tag Special
hi! link Typedef Type
hi! link lCursor Cursor
hi! link CurSearch Search
hi! link CursorLineFold CursorLine
hi! link CursorLineSign CursorLine
hi! link MessageWindow Pmenu
hi! link PopupNotification Todo

if (has('termguicolors') && &termguicolors) || has('gui_running')
  let g:terminal_ansi_colors = [s:bg, s:red, s:green, s:yellow, s:blue, s:magenta, s:cyan, s:white, s:brblack, s:red, s:green, s:yellow, s:blue, s:magenta, s:cyan, s:white]
  " Nvim uses g:terminal_color_{0-15} instead
  for i in range(g:terminal_ansi_colors->len())
    let g:terminal_color_{i} = g:terminal_ansi_colors[i]
  endfor
endif

execute 'hi Normal guifg= ' . s:fg . ' guibg= ' . s:bg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi QuickFixLine guifg= ' . s:white . ' guibg= ' . s:black . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi ColorColumn guifg= ' . s:NONE . ' guibg= ' . s:bg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi CursorColumn guifg= ' . s:NONE . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi CursorLine guifg= ' . s:NONE . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi CursorLineNr guifg= ' . s:green . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Folded guifg= ' . s:cyan . ' guibg= ' . s:white . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Conceal guifg= ' . s:white . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Cursor guifg= ' . s:bg . ' guibg= ' . s:cyan . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Directory guifg= ' . s:cyan . ' guibg= ' . s:bg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi EndOfBuffer guifg= ' . s:brblack . ' guibg= ' . s:bg . ' gui= ' . s:bold . ' cterm= ' . s:NONE
execute 'hi ErrorMsg guifg= ' . s:white . ' guibg= ' . s:bg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi FoldColumn guifg= ' . s:cyan . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi IncSearch guifg= ' . s:NONE . ' guibg= ' . s:bg . ' gui= ' . s:reverse . ' cterm= ' . s:reverse
execute 'hi LineNr guifg= ' . s:green . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi MatchParen guifg= ' . s:NONE . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi ModeMsg guifg= ' . s:NONE . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' ctermfg= ' . s:NONE . 'ctermbg=' . s:NONE . 'cterm=' . s:bold
execute 'hi MoreMsg guifg= ' . s:black . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi NonText guifg= ' . s:brblack . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Pmenu guifg= ' . s:white . ' guibg= ' . s:black . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi PmenuSbar guifg= ' . s:NONE . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi PmenuSel guifg= ' . s:bg . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi PmenuThumb guifg= ' . s:NONE . ' guibg= ' . s:white . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi PmenuMatch guifg= ' . s:fg . ' guibg= ' . s:black . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi PmenuMatchSel guifg= ' . s:fg . ' guibg= ' . s:fg . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Question guifg= ' . s:fg . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Search guifg= ' . s:bg . ' guibg= ' . s:green . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi SignColumn guifg= ' . s:cyan . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi SpecialKey guifg= ' . s:cyan . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi SpellBad guifg= ' . s:magenta . ' guibg= ' . s:NONE . ' guisp= ' . s:red . ' gui= ' . s:undercurl . 'cterm=' . s:underline
execute 'hi SpellCap guifg= ' . s:brblack . ' guibg= ' . s:NONE . ' guisp= ' . s:brblack . ' gui= ' . s:undercurl . 'cterm=' . s:underline
execute 'hi SpellLocal guifg= ' . s:green . ' guibg= ' . s:NONE . ' guisp= ' . s:green . ' gui= ' . s:undercurl . 'cterm=' . s:underline
execute 'hi SpellRare guifg= ' . s:fg . ' guibg= ' . s:NONE . ' guisp= ' . s:fg . ' gui= ' . s:undercurl . 'cterm=' . s:underline
execute 'hi StatusLine guifg= ' . s:bg . ' guibg= ' . s:cyan . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi StatusLineNC guifg= ' . s:bg . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi TabLine guifg= ' . s:bg . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi TabLineFill guifg= ' . s:NONE . ' guibg= ' . s:bg . ' gui= ' . s:reverse . ' cterm= ' . s:reverse
execute 'hi TabLineSel guifg= ' . s:cyan . ' guibg= ' . s:bg . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Terminal guifg= ' . s:cyan . ' guibg= ' . s:bg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Title guifg= ' . s:fg . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi VertSplit guifg= ' . s:bg . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Visual guifg= ' . s:bg . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi VisualNOS guifg= ' . s:NONE . ' guibg= ' . s:bg . ' gui= ' . s:bold . ' , ' . s:underline . 'cterm=' . s:underline
execute 'hi WarningMsg guifg= ' . s:magenta . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi WildMenu guifg= ' . s:bg . ' guibg= ' . s:green . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Comment guifg= ' . s:brblack . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Constant guifg= ' . s:fg . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Error guifg= ' . s:white . ' guibg= ' . s:magenta . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Function guifg= ' . s:white . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Identifier guifg= ' . s:fg . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Ignore guifg= ' . s:bg . ' guibg= ' . s:bg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Operator guifg= ' . s:magenta . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi PreProc guifg= ' . s:fg . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Repeat guifg= ' . s:white . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Special guifg= ' . s:magenta . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Statement guifg= ' . s:magenta . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Todo guifg= ' . s:brblack . ' guibg= ' . s:green . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi Type guifg= ' . s:fg . ' guibg= ' . s:NONE . ' gui= ' . s:bold . ' cterm= ' . s:bold
execute 'hi Underlined guifg= ' . s:brblack . ' guibg= ' . s:NONE . ' gui= ' . s:underline . ' cterm= ' . s:underline
execute 'hi CursorIM guifg= ' . s:NONE . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi ToolbarLine guifg= ' . s:NONE . ' guibg= ' . s:NONE . ' gui= ' . s:NONE . ' ctermfg= ' . s:NONE . ' ctermbg= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi ToolbarButton guifg= ' . s:bg . ' guibg= ' . s:bg . ' gui= ' . s:bold . ' cterm= ' . s:bold
hi! link LineNrAbove LineNr
hi! link LineNrBelow LineNr
execute 'hi DiffAdd guifg= ' . s:white . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi DiffChange guifg= ' . s:white . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi DiffText guifg= ' . s:bg . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE
execute 'hi DiffDelete guifg= ' . s:white . ' guibg= ' . s:fg . ' gui= ' . s:NONE . ' cterm= ' . s:NONE

