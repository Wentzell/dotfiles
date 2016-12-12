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
