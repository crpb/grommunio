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


