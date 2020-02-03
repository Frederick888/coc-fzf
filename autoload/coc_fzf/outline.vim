let s:prompt = 'Coc Outline> '

function! coc_fzf#outline#fzf_run() abort
  let expect_keys = join(keys(get(g:, 'fzf_action', s:default_action)), ',')
  let l:opts = {
        \ 'source': s:get_outline(),
        \ 'sink*': function('s:symbol_handler'),
        \ 'options': ['--multi','--expect='.expect_keys,
        \ '--layout=reverse-list', '--ansi', '--prompt=' . s:prompt],
        \ }
  call fzf#run(fzf#wrap(l:opts))
  call s:syntax()
endfunction

function! s:format_coc_outline_ctags(item) abort
  if len(a:item) >= 4
    let l:parts = split(a:item, "\t")
    let l:sym = parts[0]
    let l:line = substitute(parts[2], ';".*$', '', '')
    let l:type = '[' . parts[3] . ']'
    call cursor(l:line, 0)
    let [l:l, l:col] = searchpos(l:sym, 'nc', l:line)
    return l:sym . " " . l:type . " " . l:line . ',' . l:col
  else
    return ''
  endif
endfunction

function! s:format_coc_outline_docsym(item) abort
  let l:msg = a:item.text . ' [' . a:item.kind . '] ' . a:item.lnum . ',' . a:item.col
  let l:indent = ''
  let l:c = 0
  while l:c < a:item.level
    let l:indent .= '  '
    let l:c += 1
  endwhile
  return l:indent . l:msg
endfunction

function! s:get_outline() abort
  let l:symbols = CocAction('documentSymbols')
  if type(l:symbols) != v:t_list
    " ctags: try force language to filtetype
    let l:shell_cmd = "ctags -f - --excmd=number --language-force=" . &ft . " " . expand("%")
    let l:shell_cmd .= ' | sort -n --key=3'
    let l:symbols = systemlist(shell_cmd)
    if (!(len(l:symbols) && v:shell_error == 0))
      " ctags: try without forcing language
      let l:shell_cmd = "ctags -f - --excmd=number " . expand("%")
      let l:shell_cmd .= ' | sort -n --key=3'
      let l:symbols = systemlist(shell_cmd)
    endif
    let l:cur_pos = getpos('.')
    let l:return_list = v:shell_error == 0 ? map(l:symbols, 's:format_coc_outline_ctags(v:val)'):[]
    call cursor(l:cur_pos[1:2])
    return l:return_list
  else
    return map(l:symbols, 's:format_coc_outline_docsym(v:val)')
  endif
endfunction

let s:default_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

function! s:action_for(key, ...)
  let default = a:0 ? a:1 : ''
  let l:Cmd = get(get(g:, 'fzf_action', s:default_action), a:key, default)
  return l:Cmd
endfunction

function! s:syntax() abort
  if has('syntax') && exists('g:syntax_on')
    syntax case ignore
    " apply syntax on everything but prompt
    exec 'syntax match CocFzf_DiagnosticHeader /^\(\(\s*' . s:prompt . '\?.*\)\@!.\)*$/'
    syntax match CocFzf_DiagnosticSymbol /\v^>\?\s*\S\+/ contained containedin=CocFzf_DiagnosticHeader
    syntax match CocFzf_DiagnosticType /\v\s\[.*\]\s/ contained containedin=CocFzf_DiagnosticHeader
    syntax match CocFzf_DiagnosticLine /\d\+/ contained containedin=CocFzf_DiagnosticHeader
    syntax match CocFzf_DiagnosticColumn /,\d\+$/ contained containedin=CocFzf_DiagnosticHeader
    highlight default link CocFzf_DiagnosticSymbol Normal
    highlight default link CocFzf_DiagnosticType Typedef
    highlight default link CocFzf_DiagnosticLine Comment
    highlight default link CocFzf_DiagnosticColumn Ignore
  endif
endfunction

function! s:symbol_handler(sym) abort
  let cmd = s:action_for(a:sym[0])
  if !empty(cmd) && stridx('edit', cmd) < 0
    execute 'silent' cmd
  endif
  let l:parsed = s:parse_symbol(a:sym[1:])
  call cursor(l:parsed["lnum"], l:parsed["col"])
  normal! zz
endfunction

function! s:parse_symbol(sym) abort
  let l:match = matchlist(a:sym, '^\s*\(.*\) \[\([^[]*\)\] \(\d\+\),\(\d\+\)')[1:4]
  if empty(l:match) || empty(l:match[0])
    return
  endif
  return ({'text': l:match[0], 'kind': l:match[1], 'lnum': l:match[2], 'col': l:match[3]})
endfunction
