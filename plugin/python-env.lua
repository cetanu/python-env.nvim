-- Plugin entry point
-- This file is automatically loaded by Neovim

if vim.g.plugin_python_env_loaded then
	return
end
vim.g.plugin_python_env_loaded = 1

-- Initialize the plugin with default settings
require("python-env").setup()

