if exists("g:loaded_tidal") || &cp || v:version < 700
  finish
endif
let g:loaded_tidal = 1
let s:parent_path = fnamemodify(expand("<sfile>"), ":p:h:s?/plugin??")

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Default config
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Attempts to find a tidal boot file in this or any parent directory.
function s:FindTidalBoot()
  for name in ["BootTidal.hs", "Tidal.ghci", "boot.tidal"]
    let tidal_boot_file = findfile(name, ".".';')
    if !empty(tidal_boot_file)
      return tidal_boot_file
    endif
  endfor
endfunction

" Attempts to find a supercollider startup file in this or any parent dir.
function s:FindScBoot()
  for name in ["boot.sc", "boot.scd"]
    let sc_boot_file = findfile(name, ".".';')
    if !empty(sc_boot_file)
      return sc_boot_file
    endif
  endfor
endfunction

if !exists("g:tidal_target")
  if has('nvim') || has('terminal')
    let g:tidal_target = "terminal"
  else
    let g:tidal_target = "tmux"
  endif
endif

if !exists("g:tidal_paste_file")
  let g:tidal_paste_file = tempname()
endif

if !exists("g:tidal_default_config")
  let g:tidal_default_config = { "socket_name": "default", "target_pane": ":0.1" }
endif

if !exists("g:tidal_preserve_curpos")
  let g:tidal_preserve_curpos = 1
endif

if !exists("g:tidal_flash_duration")
  let g:tidal_flash_duration = 150
endif

if !exists("g:tidal_ghci")
  let g:tidal_ghci = "ghci"
endif

if !exists("g:tidal_boot_fallback")
  let g:tidal_boot_fallback = s:parent_path . "/Tidal.ghci"
endif

if !exists("g:tidal_boot")
  let g:tidal_boot = s:FindTidalBoot()
  if empty(g:tidal_boot)
    let g:tidal_boot = g:tidal_boot_fallback
  endif
endif

if !exists("g:tidal_superdirt_enable")
  " Allow vim-tidal to automatically start SuperDirt. Disabled by default.
  let g:tidal_superdirt_enable = 0
endif

if !exists("g:tidal_sclang")
  let g:tidal_sclang = "sclang"
endif

" Allow vim-tidal to automatically start supercollider. Disabled by default.
if !exists("g:tidal_sc_enable")
  let g:tidal_sc_enable = 0
endif

if !exists("g:tidal_sc_boot_fallback")
  let g:tidal_sc_boot_fallback = s:parent_path . "/boot.sc"
endif

if !exists("g:tidal_sc_boot")
  let g:tidal_sc_boot = s:FindScBoot()
  if empty(g:tidal_sc_boot)
    let g:tidal_sc_boot = g:tidal_sc_boot_fallback
  endif
endif

if !exists("g:tidal_sc_boot_cmd")
  " A command that can be run from the terminal to start supercollider.
  " The default assumes `SuperDirt` is installed.
  let g:tidal_sc_boot_cmd = g:tidal_sclang . " " . g:tidal_sc_boot
endif

if !exists('g:tidal_split_direction')
  let g:tidal_split_direction = 'below'
endif

if filereadable(s:parent_path . "/.dirt-samples")
  let &l:dictionary .= ',' . s:parent_path . "/.dirt-samples"
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tmux
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:TmuxSend(config, text)
  let l:prefix = "tmux -L " . shellescape(a:config["socket_name"])
  " use STDIN unless configured to use a file
  if !exists("g:tidal_paste_file")
    call system(l:prefix . " load-buffer -", a:text)
  else
    call s:WritePasteFile(a:text)
    call system(l:prefix . " load-buffer " . g:tidal_paste_file)
  end
  call system(l:prefix . " paste-buffer -d -t " . shellescape(a:config["target_pane"]))
endfunction

function! s:TmuxPaneNames(A,L,P)
  let format = '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name}#{?window_active, (active),}'
  return system("tmux -L " . shellescape(b:tidal_config['socket_name']) . " list-panes -a -F " . shellescape(format))
endfunction

function! s:TmuxConfig() abort
  if !exists("b:tidal_config")
    let b:tidal_config = {"socket_name": "default", "target_pane": ":"}
  end

  let b:tidal_config["socket_name"] = input("tmux socket name: ", b:tidal_config["socket_name"])
  let b:tidal_config["target_pane"] = input("tmux target pane: ", b:tidal_config["target_pane"], "custom,<SNR>" . s:SID() . "_TmuxPaneNames")
  if b:tidal_config["target_pane"] =~ '\s\+'
    let b:tidal_config["target_pane"] = split(b:tidal_config["target_pane"])[0]
  endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Terminal
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:tidal_term_ghci = -1
let s:tidal_term_sc = -1

" NVim and VIM8 Terminal Implementation
" =====================================
function! s:TerminalOpen()
  if has('nvim')
    let current_buf = bufnr('%')  " Store buffer number instead of window number
    let current_height = winheight(0)
    
    if s:tidal_term_ghci == -1
        if g:tidal_split_direction == 'below'
            :exe "set splitbelow"
            execute "split term://" . g:tidal_ghci . " -ghci-script=" . g:tidal_boot
        elseif g:tidal_split_direction == 'right'
            :exe "set splitright"
            execute "vsplit term://" . g:tidal_ghci . " -ghci-script=" . g:tidal_boot
            execute "resize " . current_height
        elseif g:tidal_split_direction == 'left'
            execute "leftabove vsplit term://" . g:tidal_ghci . " -ghci-script=" . g:tidal_boot
            execute "resize " . current_height
        endif
        
        let s:tidal_term_ghci = b:terminal_job_id
        sleep 500m
        :exe "normal G"
        
        if g:tidal_split_direction == 'below'
            :exe "normal 10\<c-w>_"
        endif
    endif
    
    if g:tidal_sc_enable == 1 && s:tidal_term_sc == -1
        if g:tidal_split_direction == 'below'
            execute "vsplit term://" . g:tidal_sc_boot_cmd
        else
            execute "split term://" . g:tidal_sc_boot_cmd
        endif
        let s:tidal_term_sc = b:terminal_job_id
        :exe "normal G"
    endif
    
    " Find and switch to the window containing our original buffer
    let target_win = bufwinnr(current_buf)
    if target_win != -1
        execute target_win .. "wincmd w"
    endif
    
  elseif has('terminal')
    let current_buf = bufnr('%')  " Store buffer number instead of window number
    let current_height = winheight(0)
    
    if s:tidal_term_ghci == -1
      if g:tidal_split_direction == 'below'
        execute "below split"
        let s:tidal_term_ghci = term_start((g:tidal_ghci . " -ghci-script=" . g:tidal_boot), #{
              \ term_name: 'tidal',
              \ term_rows: 10,
              \ norestore: 1,
              \ curwin: 1,
              \ })
      elseif g:tidal_split_direction == 'right'
        execute "vert rightbelow split"
        let s:tidal_term_ghci = term_start((g:tidal_ghci . " -ghci-script=" . g:tidal_boot), #{
              \ term_name: 'tidal',
              \ term_rows: current_height,
              \ norestore: 1,
              \ curwin: 1,
              \ })
      elseif g:tidal_split_direction == 'left'
        execute "vert leftabove split"
        let s:tidal_term_ghci = term_start((g:tidal_ghci . " -ghci-script=" . g:tidal_boot), #{
              \ term_name: 'tidal',
              \ term_rows: current_height,
              \ norestore: 1,
              \ curwin: 1,
              \ })
      endif
    endif
    
    if g:tidal_sc_enable == 1 && s:tidal_term_sc == -1
      if g:tidal_split_direction == 'below'
        execute "vert split"
      else
        execute "below split"
      endif
      let s:tidal_term_sc = term_start(g:tidal_sc_boot_cmd, #{
           \ term_name: 'supercollider',
           \ term_rows: 10,
           \ norestore: 1,
           \ curwin: 1,
           \ })
    endif
    
    " Find and switch to the window containing our original buffer
    let target_win = bufwinnr(current_buf)
    if target_win != -1
        execute target_win .. "wincmd w"
    endif
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun

function! s:WritePasteFile(text)
  " could check exists("*writefile")
  call system("cat > " . g:tidal_paste_file, a:text)
endfunction

function! s:_EscapeText(text)
  if exists("&filetype")
    let custom_escape = "_EscapeText_" . substitute(&filetype, "[.]", "_", "g")
    if exists("*" . custom_escape)
      let result = call(custom_escape, [a:text])
    end
  end

  " use a:text if the ftplugin didn't kick in
  if !exists("result")
    let result = a:text
  end

  " return an array, regardless
  if type(result) == type("")
    return [result]
  else
    return result
  end
endfunction

function! s:TidalGetConfig()
  if !exists("b:tidal_config")
    if exists("g:tidal_default_config")
      let b:tidal_config = g:tidal_default_config
    else
      call s:TidalDispatch('Config')
    end
  end
endfunction

function! s:TidalFlashVisualSelection()
  " Redraw to show current visual selection, and sleep
  redraw
  execute "sleep " . g:tidal_flash_duration . " m"
  " Then leave visual mode
  silent exe "normal! vv"
endfunction

function! s:TidalSendOp(type, ...) abort
  call s:TidalGetConfig()

  let sel_save = &selection
  let &selection = "inclusive"
  let rv = getreg('"')
  let rt = getregtype('"')

  if a:0  " Invoked from Visual mode, use '< and '> marks.
    silent exe "normal! `<" . a:type . '`>y'
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  elseif a:type == 'block'
    silent exe "normal! `[\<C-V>`]\y"
  else
    silent exe "normal! `[v`]y"
  endif

  call setreg('"', @", 'V')
  call s:TidalSend(@")

  " Flash selection
  if a:type == 'line'
    silent exe "normal! '[V']"
    call s:TidalFlashVisualSelection()
  endif

  let &selection = sel_save
  call setreg('"', rv, rt)

  call s:TidalRestoreCurPos()
endfunction

function! s:TidalSendRange() range abort
  call s:TidalGetConfig()

  let rv = getreg('"')
  let rt = getregtype('"')
  silent execute a:firstline . ',' . a:lastline . 'yank'
  call s:TidalSend(@")
  call setreg('"', rv, rt)
endfunction

function! s:TidalSendLines(count) abort
  call s:TidalGetConfig()

  let rv = getreg('"')
  let rt = getregtype('"')

  silent execute "normal! " . a:count . "yy"

  call s:TidalSend(@")
  call setreg('"', rv, rt)

  " Flash lines
  silent execute "normal! V"
  if a:count > 1
    silent execute "normal! " . (a:count - 1) . "\<Down>"
  endif
  call s:TidalFlashVisualSelection()
endfunction

function! s:TidalStoreCurPos()
  if g:tidal_preserve_curpos == 1
    if exists("*getcurpos")
      let s:cur = getcurpos()
    else
      let s:cur = getpos('.')
    endif
  endif
endfunction

function! s:TidalRestoreCurPos()
  if g:tidal_preserve_curpos == 1
    call setpos('.', s:cur)
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Public interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:TidalSend(text)
  call s:TidalGetConfig()

  let pieces = s:_EscapeText(a:text)
  for piece in pieces
    call s:TidalDispatch('Send', b:tidal_config, piece)
  endfor
endfunction

function! s:TidalConfig() abort
  call inputsave()
  call s:TidalDispatch('Config')
  call inputrestore()
endfunction

" delegation
function! s:TidalDispatch(name, ...)
  let target = substitute(tolower(g:tidal_target), '\(.\)', '\u\1', '') " Capitalize
  return call("s:" . target . a:name, a:000)
endfunction

function! s:TidalHush()
  execute 'TidalSend1 hush'
endfunction

function! s:TidalSilence(stream)
  silent execute 'TidalSend1 d' . a:stream . ' silence'
endfunction

function! s:TidalPlay(stream)
  let res = search('^\s*d' . a:stream)
  if res > 0
    silent execute "normal! vip:TidalSend\<cr>"
    silent execute "normal! vip"
    call s:TidalFlashVisualSelection()
  else
    echo "d" . a:stream . " was not found"
  endif
endfunction

function! s:TidalGenerateCompletions(path)
  let l:exe = s:parent_path . "/bin/generate-completions"
  let l:output_path = s:parent_path . "/.dirt-samples"

  if !empty(a:path)
    let l:sample_path = a:path
  else
    if has('macunix')
      let l:sample_path = "~/Library/Application Support/SuperCollider/downloaded-quarks/Dirt-Samples"
    elseif has('unix')
      let l:sample_path = "~/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples"
    endif
  endif
  " generate completion file
  silent execute '!' . l:exe shellescape(expand(l:sample_path)) shellescape(expand(l:output_path))
  echo "Generated dictionary of dirt-samples"
  " setup completion
  let &l:dictionary .= ',' . l:output_path
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Setup key bindings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

command -bar -nargs=0 TidalConfig call s:TidalConfig()
command -range -bar -nargs=0 TidalSend <line1>,<line2>call s:TidalSendRange()
command -nargs=+ TidalSend1 call s:TidalSend(<q-args>)

command! -nargs=0 TidalHush call s:TidalHush()
command! -nargs=1 TidalSilence call s:TidalSilence(<args>)
command! -nargs=1 TidalPlay call s:TidalPlay(<args>)
command! -nargs=? TidalGenerateCompletions call s:TidalGenerateCompletions(<q-args>)

noremap <SID>Operator :<c-u>call <SID>TidalStoreCurPos()<cr>:set opfunc=<SID>TidalSendOp<cr>g@

noremap <unique> <script> <silent> <Plug>TidalRegionSend :<c-u>call <SID>TidalSendOp(visualmode(), 1)<cr>
noremap <unique> <script> <silent> <Plug>TidalLineSend :<c-u>call <SID>TidalSendLines(v:count1)<cr>
noremap <unique> <script> <silent> <Plug>TidalMotionSend <SID>Operator
noremap <unique> <script> <silent> <Plug>TidalParagraphSend <SID>Operatorip
noremap <unique> <script> <silent> <Plug>TidalConfig :<c-u>TidalConfig<cr>
