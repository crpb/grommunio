" Uncomment the following to have Vim jump to the last position when
" reopening a file
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Uncomment the following to have Vim load indentation rules and plugins
" according to the detected filetype.
filetype plugin indent on

" colorscheme wood
" colorscheme desert
" colorscheme anokha
if &diff
	colorscheme torte
endif

hi Normal guibg=NONE ctermbg=NONE

" Spellchecker
" setlocal spell spelllang=en_us

" More TABS - vim -p *.foo
set tabpagemax=20

" Show linenumbers
set number

" The following are commented out as they cause vim to behave a lot
" differently from regular Vi. They are highly recommended though.
set showcmd   " Show (partial) command in status line.

set showmatch   " Show matching brackets.
set ignorecase    " Do case insensitive matching
set smartcase    " Do smart case matching
set incsearch    " Incremental search
set autowrite    " Automatically save before commands like :next and :make
set hidden   " Hide buffers when they are abandoned
set mouse=a   " Enable mouse usage (all modes)
set mousemodel=popup_setpos

syntax on

" Allow modelines
set modeline modelines=5

" set tabstop=2     " Size of a hard tabstop (ts).
" set shiftwidth=2  " Size of an indentation (sw).
" set expandtab     " Always uses spaces instead of tab characters (et).
" set softtabstop=2 " Number of spaces a <Tab> counts for. When 0, featuer is off (sts).
set autoindent    " Copy indent from current line when starting a new line.
"" set smartindent   " Smart Indent?
set smarttab      " Inserts blanks on a <Tab> key (as per sw, ts and sts).
set hlsearch    " HIGHLIGHT ALLES
highlight Search cterm=NONE ctermfg=white ctermbg=88
set cursorline cursorcolumn colorcolumn=81
highlight CursorColumn ctermbg=4
highlight ColorColumn ctermbg=8 guibg=lightgrey

" SET PASTE
set pastetoggle=<F2>

" ALE aeh BIER!

" Enable completion where available.
" This setting must be set before ALE is loaded.
" Set this. Airline will handle the rest.
let g:airline#extensions#ale#enabled = 1
" You should not turn this setting on if you wish to use ALE as a completion
" source for other completion plugins, like Deoplete.
let g:ale_completion_enabled = 0
let g:ale_lint_on_text_changed = 0
let g:ale_lint_on_enter = 0
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_save = 1
" BASHATE
let g:ale_sh_bashate_options = '-i E006,E004,E003,E002'
" SHELLCHECK
let g:ale_sh_shellcheck_options = '-a -e SC2034'
" PYLINT
:let g:ale_python_pylint_options='--disable=C0103'
" WITH AIRLINE ALREADY COVERED
" let g:ale_echo_msg_error_str = 'E'
" let g:ale_echo_msg_warning_str = 'W'
" let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
" Write this in your vimrc file
" let g:ale_set_loclist = 1
let g:ale_set_quickfix = 0
" Set this if you want to.
let g:ale_list_window_size = 3
let g:ale_keep_list_window_open = 0
let g:ale_open_list = 1
" This can be useful if you are combining ALE with
" some other plugin which sets quickfix errors, etc.
" let g:ale_keep_list_window_open = 1
augroup CloseLoclistWindowGroup
  autocmd!
  autocmd QuitPre * if empty(&buftype) | lclose | endif
augroup END

" OOOLD
" " SYNTASTIC
" set statusline+=%#warningmsg#
" set statusline+=%{SyntasticStatuslineFlag()}
" set statusline+=%*
" 
" let g:syntastic_always_populate_loc_list = 1
" let g:syntastic_auto_loc_list = 1
" let g:syntastic_check_on_open = 1
" let g:syntastic_check_on_wq = 1
" let g:syntastic_loc_list_winminheight = 3
" " RST-CHECK VIA SPHINX
" let g:syntastic_rst_checkers=['sphinx']
" " Shellcheck External Sources
" let g:syntastic_sh_shellcheck_args="-a"
" let g:syntastic_shell = "/bin/bash"
" let g:loaded_syntastic_ansible_ansible_lint_checker = 1
" " :SyntasticCheck
" " let g:loaded_syntastic_zsh_zsh_checker = 0 
" function! SyntasticCheckHook(errors)
"     if !empty(a:errors)
"         let g:syntastic_loc_list_height = min([len(a:errors), 5])
"     endif
" endfunction
" " CommandT
" nnoremap <silent> <Leader>T :CommandTTag<CR>

" Treat TABS AS EVIL
" match Error /\t/
" match Todo /\t/

command Td :call Tidy()
function Tidy()
  let filename=expand("%:p") " escapes for bash
  let filename=substitute(filename, " ", "\\\\ ", "g")
  let filename=substitute(filename, "(", "\\\\(", "g")
  let filename=substitute(filename, ")", "\\\\)", "g")
  let filename=substitute(filename, "[", "\\\\[", "g")
  let filename=substitute(filename, "]", "\\\\]", "g")
  let filename=substitute(filename, "&", "\\\\&", "g")
  let filename=substitute(filename, "!", "\\\\!", "g")
  let filename=substitute(filename, ",", "\\\\,", "g")
  let filename=substitute(filename, "'", "?", "g")
  let filename2=substitute(filename, ".*", "&.tidy.htm", "")
  let filename3=substitute(filename, ".*", "&.errors.tidy.txt", "")
  execute "!tidy "."-f ".filename3." ".filename." > ".filename2.""
endfunction

autocmd BufRead,BufNewFile ~/.dotfiles/xresources/* set syntax=xdefaults
autocmd BufRead,BufNewFile *.ssh set syntax=sshconfig
autocmd BufRead,BufNewFile *.ssh set expandtab! smarttab!
autocmd BufRead,BufNewFile *.txt set textwidth=80

" TMUX MOUSE FIX
if has("mouse_sgr")
  set ttymouse=sgr
else
  set ttymouse=xterm2
end

"packadd! ale

" Filebrowser
let g:netrw_liststyle = 1
let g:netrw_banner = 1
" open in 1=horiz,2=vert,3=tab,4=prevw
let g:netrw_browse_split = 4
" width
let g:netrw_winsize = 20

let g:netrw_banner = 0
let g:netrw_liststyle = 4
let g:netrw_browse_split = 3
let g:netrw_altv = 1
let g:netrw_winsize = 25
"augroup ProjectDrawer
"  if @% == ""
"    autocmd!
"      autocmd VimEnter * :Vexplore!
"  endif
"augroup END

syntax on
" Enable completion where available.
" This setting must be set before ALE is loaded.
" Set this. Airline will handle the rest.
let g:airline#extensions#ale#enabled = 1
" You should not turn this setting on if you wish to use ALE as a completion
" source for other completion plugins, like Deoplete.
let g:ale_completion_enabled = 0
let g:ale_lint_on_text_changed = 0
let g:ale_lint_on_enter = 0
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_save = 1
let g:ale_sh_bashate_options = '-i E006,E004,E003,E002'
let g:ale_sh_shellcheck_options = '-a'
" WITH AIRLINE ALREADY COVERED
" let g:ale_echo_msg_error_str = 'E'
" let g:ale_echo_msg_warning_str = 'W'
" let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'
" Write this in your vimrc file
" let g:ale_set_loclist = 1
let g:ale_set_quickfix = 0
" Set this if you want to.
let g:ale_list_window_size = 6
let g:ale_keep_list_window_open = 0
let g:ale_open_list = 1
" This can be useful if you are combining ALE with
" some other plugin which sets quickfix errors, etc.
" let g:ale_keep_list_window_open = 1
augroup CloseLoclistWindowGroup
  autocmd!
  autocmd QuitPre * if empty(&buftype) | lclose | endif
augroup END


