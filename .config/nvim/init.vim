set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" ---- Language Server Setup -----

lua << EOF
  vim.lsp.set_log_level("debug")
  require'lspconfig'.clangd.setup({
    cmd       = { 'clangd', '--all-scopes-completion', '--background-index', '--completion-style=bundled', '--header-insertion=iwyu', '--clang-tidy' };
    filetypes = { 'c', 'h', 'cpp', 'cxx', 'hxx', 'objc', 'objcpp' }
  })
  require'lspconfig'.ruff.setup{} -- pip install ruff ruff-lsp

  -- Disable semantic highlighting
  for _, group in ipairs(vim.fn.getcompletion("@lsp", "highlight")) do
    vim.api.nvim_set_hl(0, group, {})
  end
EOF

" ---- Copilot Chat Setup -----
lua << EOF
require("CopilotChat").setup {
  -- See Configuration section for options
}
EOF

" ---- Fix Diff View to not change syntax highlighting ---- "
hi DiffAdd ctermfg=none
hi DiffDelete ctermfg=none
hi DiffChange ctermfg=none
hi DiffText ctermfg=none

" ---- Copilot ---- "
imap <silent><script><expr> <C-l> copilot#Accept("\<CR>")
imap <silent> <C-j> <Plug>(copilot-next)
imap <silent> <C-k> <Plug>(copilot-previous)
imap <silent> <C-/> <Plug>(copilot-dismiss)
let g:copilot_no_tab_map = v:true
let g:copilot_assume_mapped = v:true

" ---- Toggle Diagnostics ---- "
let g:diagnostics_is_on=1
function! ToggleDiagnostics()
  if g:diagnostics_is_on
    echo "Diagnostics Off"
    let g:diagnostics_is_on=0
    lua vim.diagnostic.disable()
  else
    echo "Diagnostics On"
    let g:diagnostics_is_on=1
    lua vim.diagnostic.enable()
  endif
endfunction
autocmd Syntax c,cpp,python,julia,sh,json nnoremap <buffer> <leader><leader>d :call ToggleDiagnostics()<CR>

function! DiagnosticsSetup()
  if &diff
    lua vim.diagnostic.disable()
  endif
endfunction
autocmd Syntax c,cpp,python,julia,sh,json call DiagnosticsSetup()

" ---- LSP Bindings ---- "
autocmd Syntax c,cpp,python,julia,sh,json nnoremap <buffer> <C-]> :lua vim.lsp.buf.definition()<CR>
autocmd Syntax c,cpp,python,julia,sh,json xnoremap <buffer> <C-]> :lua vim.lsp.buf.definition()<CR>
autocmd Syntax c,cpp,python,julia,sh,json nnoremap <buffer> <C-h> :lua vim.lsp.buf.rename()<CR>
autocmd Syntax c,cpp,python,julia,sh,json xnoremap <buffer> <C-h> :lua vim.lsp.buf.rename()<CR>
autocmd Syntax c,cpp,python,julia,sh,json nnoremap <buffer> == :lua vim.lsp.buf.format()<CR>
autocmd Syntax c,cpp,python,julia,sh,json xnoremap <buffer> == :lua vim.lsp.buf.formatexpr()<CR>
autocmd Syntax c,cpp,python,julia,sh,json nnoremap <buffer> <leader><leader>f :lua vim.lsp.buf.code_action()<CR>

autocmd Syntax c,cpp nnoremap <Leader>of :ClangdSwitchSourceHeader<cr>

augroup DisableLineNumbersInDiff
  autocmd!
  autocmd WinEnter * if &diff | setlocal nonumber | endif
augroup END

lua << EOF

  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    -- Customizing how diagnostics are displayed
    -- See :help on_publish_diagnostics
    signs = { min = vim.diagnostic.severity.WARN },
    underline = { min = vim.diagnostic.severity.ERROR },
    update_in_insert = false,
    severity_sort = true,
    virtual_text = {
      -- Show source in diagnostics (neovim 0.6+ only)
      -- source = "always",  -- Or "if_many"
      -- Only for Errors
      min = vim.diagnostic.severity.ERROR,
      -- Change prefix/character preceding the diagnostics' virtual text
      prefix = '▎',
    }
  })

  -- Show line diagnostics automatically in hover window
  vim.o.updatetime = 500
  vim.cmd [[autocmd CursorHold * lua vim.diagnostic.open_float({focusable=false})]]

  -- Customizing how diagnostic symbols
  local signs = { Error = "⛔", Warn = "⚡", Hint = "💡", Info = "ℹ" }

  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end
EOF

" Other useful lsp commands
"vim.lsp.diagnostic.goto_prev()
"vim.lsp.diagnostic.goto_next()
"vim.lsp.buf.references()
"vim.lsp.buf.range_formatting()
"vim.lsp.buf.range_code_action()
"vim.lsp.buf.hover()

" ---- Auto Completion -----
lua << EOF
  -- Add additional capabilities supported by nvim-cmp
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
  
  local lspconfig = require('lspconfig')
  
  -- Enable some language servers with the additional completion capabilities offered by nvim-cmp
  local servers = { 'clangd', 'ruff' }
  for _, lsp in ipairs(servers) do
    lspconfig[lsp].setup {
      -- on_attach = my_custom_on_attach,
      capabilities = capabilities,
    }
  end
  
  -- Set completeopt to have a better completion experience
  vim.o.completeopt = 'menuone,noselect'
  
  -- luasnip setup
  local luasnip = require 'luasnip'
  
  -- nvim-cmp setup
  local cmp = require 'cmp'
  cmp.setup {
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body)
      end,
    },
    mapping = {
      ['<C-p>'] = cmp.mapping.select_prev_item(),
      ['<C-n>'] = cmp.mapping.select_next_item(),
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm {
        behavior = cmp.ConfirmBehavior.Replace,
        select = true,
      },
      ['<Tab>'] = function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end,
      ['<S-Tab>'] = function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end,
    },
    sources = {
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
    },
  }
EOF
