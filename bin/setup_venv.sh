#!/usr/bin/env zsh
python3 -m venv --system-site-packages ~/opt/myenv
echo "# Python
export PYTHONPATH=\$HOME/opt/myenv/lib/python3.13/site-packages:\$PYTHONPATH
export PATH=\$HOME/opt/myenv/bin:\$PATH
export VIRTUAL_ENV=\$HOME/opt/myenv
" >> ~/.zprofile
pip install ninja compdb ruff ruff-lsp mako scikit-image nbsphinx sphinx-rtd-theme myst-parser linkify-it-py sympy matplotlib
