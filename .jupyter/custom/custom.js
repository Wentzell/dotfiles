// Vim bindings for Jupyter Notebook
require([
  'nbextensions/vim_binding/vim_binding',   // depends your installation
], function() {
  // Map ;; to <Esc>
  CodeMirror.Vim.map(";;", "<Esc>", "insert");

  // Map bindings for quick movement ( not working in Chrome )
  CodeMirror.Vim.map(";j", "<C-D>", "normal");
  CodeMirror.Vim.map(";k", "<C-U>", "normal");
  CodeMirror.Vim.map(";j", "<C-D>", "visual");
  CodeMirror.Vim.map(";k", "<C-U>", "visual");
});

// Configure Jupyter Keymap
require([
  'nbextensions/vim_binding/vim_binding',
  'base/js/namespace',
], function(vim_binding, ns) {
  // Add post callback
  vim_binding.on_ready_callbacks.push(function(){
    var km = ns.keyboard_manager;
    // Allow Ctrl-2 to change the cell mode into Markdown in Vim normal mode
    km.edit_shortcuts.add_shortcut('ctrl-2', 'vim-binding:change-cell-to-markdown', true);
    // Update Help
    km.edit_shortcuts.events.trigger('rebuild.QuickHelp');
  });
});
