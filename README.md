# python-env.nvim

A neovim plugin that automatically detects Python projects and sets up
environment variables to hook up your editor to the correct python runtime.

## Features

- Automatically detects Python projects by looking for:
  - `pyproject.toml`
  - `poetry.lock`
  - `uv.lock`
  - Uses **Poetry** when `poetry.lock` is present
  - Uses **uv** when `uv.lock` is present
  - Falls back to configured tool preference order when no specific lock files are found

I'm not that interested in supporting other tools as I don't use them, but if
you want, send over a PR

- Activates the environment when you enter a Python project directory
- Can restore the original environment when needed
- Shows notifications when environments are activated
- Optional debug logging for troubleshooting

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "cetanu/python-env.nvim",
  config = function()
    require("python-env").setup({
      -- Optional configuration
    })
  end,
}
```

## Configuration

I've tried to set sane defaults, but you can change them if you like:

```lua
require("python-env").setup({
  -- File patterns to detect Python projects
  project_files = {
    "pyproject.toml",
    "poetry.lock", 
  },
  
  -- Tools to try in order of preference
  tools = { "uv", "poetry", },
  
  -- Whether to automatically setup on directory change
  auto_setup = true,
  
  -- Whether to show notifications
  notify = true,
  
  -- Debug mode (shows detailed logging)
  debug = false
})
```

## Commands

- `:PythonEnvSetup` - Manually setup Python environment for current project
- `:PythonEnvRestore` - Restore original environment variables
- `:PythonEnvInfo` - Show information about the current Python environment

## How It Works

1. The plugin searches upward from the current directory for Python project files
2. It determines which tool to use based on lock files:
   - If `poetry.lock` exists, it prioritizes Poetry
   - If `uv.lock` exists, it prioritizes uv
   - If no specific lock files are found, it tries tools in the configured preference order
3. It checks which Python environment tools are available on your system
4. It uses the determined tool to find the project's virtual environment
5. It sets the following environment variables:
   - `VIRTUAL_ENV` - Path to the virtual environment
   - `PATH` - Prepends the virtual environment's bin directory
   - `PYTHON` - Path to the Python executable

## Supported Tools

### uv
The plugin looks for `.venv` directories or uses `uv python find` to locate the
Python interpreter.

### Poetry
Uses `poetry env info --path` to get the virtual environment path.

## Troubleshooting

### Enable Debug Mode
```lua
require("python-env").setup({
  debug = true
})
```

### Check Environment Status
Use `:PythonEnvInfo` to see the current environment status.

### Manual Setup
If auto-setup isn't working, try `:PythonEnvSetup` to manually activate the environment.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

FSL-1.1-MIT, see LICENSE.md for details
