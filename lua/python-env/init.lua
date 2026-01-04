local M = {}

local default_config = {
	project_files = {
		"pyproject.toml",
		"poetry.lock",
		"uv.lock",
	},
	-- Tools to try in order of preference
	tools = { "uv", "poetry" },
	auto_setup = true,
	notify = true,
	debug = false,
}

local config = default_config
local current_env = nil
local project_envs = {}
local command_cache = {}

local function log(msg, level)
	if config.debug or level == "error" then
		vim.notify("[python-env] " .. msg, level == "error" and vim.log.levels.ERROR or vim.log.levels.INFO)
	end
end

local function notify(msg)
	if config.notify then
		vim.notify("[python-env] " .. msg, vim.log.levels.INFO)
	end
end

local function command_exists(cmd)
	if command_cache[cmd] ~= nil then
		return command_cache[cmd]
	end

	local handle = io.popen("which " .. cmd .. " 2>/dev/null")
	if handle then
		local result = handle:read("*a")
		handle:close()
		local exists = result ~= ""
		command_cache[cmd] = exists
		return exists
	end

	command_cache[cmd] = false
	return false
end

local function find_project_root(start_path)
	start_path = start_path or vim.fn.getcwd()
	local path = vim.fn.fnamemodify(start_path, ":p")

	while path ~= "/" do
		local found_files = {}
		for _, file in ipairs(config.project_files) do
			if vim.fn.filereadable(path .. "/" .. file) == 1 then
				log("Found project file: " .. path .. "/" .. file, "debug")
				table.insert(found_files, file)
			end
		end

		if #found_files > 0 then
			return path, found_files
		end

		path = vim.fn.fnamemodify(path, ":h")
	end

	return nil, nil
end

local function execute_command(cmd, cwd)
	local full_cmd = cwd and ("cd " .. vim.fn.shellescape(cwd) .. " && " .. cmd) or cmd
	log("Executing: " .. full_cmd, "debug")

	local handle = io.popen(full_cmd .. " 2>&1")
	if not handle then
		log("Failed to execute command: " .. full_cmd, "error")
		return nil
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		log("Command failed: " .. full_cmd, "error")
		log("Output: " .. (result or ""), "error")
		return nil
	end

	return result and result:gsub("%s+$", "") or ""
end

local function get_uv_env(project_root)
	if not command_exists("uv") then
		return nil
	end

	log("Trying uv for environment setup", "debug")

	-- Check if there's a .venv directory or uv project
	local venv_path = project_root .. "/.venv"
	if vim.fn.isdirectory(venv_path) == 1 then
		local python_path = venv_path .. "/bin/python"
		if vim.fn.executable(python_path) == 1 then
			return {
				VIRTUAL_ENV = venv_path,
				PATH = venv_path .. "/bin:" .. vim.env.PATH,
				PYTHON = python_path,
			}
		end
	end

	local result = execute_command("uv python find", project_root)
	if result then
		local python_path = result:match("([^\n]+)")
		if python_path and vim.fn.executable(python_path) == 1 then
			local venv_dir = vim.fn.fnamemodify(python_path, ":h:h")
			return {
				VIRTUAL_ENV = venv_dir,
				PATH = vim.fn.fnamemodify(python_path, ":h") .. ":" .. vim.env.PATH,
				PYTHON = python_path,
			}
		end
	end

	return nil
end

local function get_poetry_env(project_root)
	if not command_exists("poetry") then
		return nil
	end

	log("Trying poetry for environment setup", "debug")

	local result = execute_command("poetry env info --path", project_root)
	if result and result ~= "" then
		local venv_path = result:match("([^\n]+)")
		if venv_path and vim.fn.isdirectory(venv_path) == 1 then
			local python_path = venv_path .. "/bin/python"
			if vim.fn.executable(python_path) == 1 then
				return {
					VIRTUAL_ENV = venv_path,
					PATH = venv_path .. "/bin:" .. vim.env.PATH,
					PYTHON = python_path,
				}
			end
		end
	end

	return nil
end

local function determine_preferred_tool(project_files)
	-- Tool-specific lock files that indicate which tool should be preferred
	local tool_indicators = {
		poetry = { "poetry.lock" },
		uv = { "uv.lock" },
	}

	-- Check for tool-specific lock files first
	for tool, indicators in pairs(tool_indicators) do
		for _, indicator in ipairs(indicators) do
			for _, found_file in ipairs(project_files) do
				if found_file == indicator then
					log("Found " .. indicator .. ", preferring " .. tool, "debug")
					return tool
				end
			end
		end
	end

	-- If no specific lock files found, fall back to configured tool order
	return nil
end

local function get_project_env(project_root, project_files)
	local env_getters = {
		uv = get_uv_env,
		poetry = get_poetry_env,
	}

	-- First, try to determine the preferred tool based on lock files
	local preferred_tool = determine_preferred_tool(project_files or {})

	if preferred_tool and env_getters[preferred_tool] and command_exists(preferred_tool) then
		log("Trying preferred tool: " .. preferred_tool, "debug")
		local env = env_getters[preferred_tool](project_root)
		if env then
			log("Successfully got environment from preferred tool " .. preferred_tool, "debug")
			return env, preferred_tool
		else
			log("Preferred tool " .. preferred_tool .. " failed, falling back to configured order", "debug")
		end
	end

	-- Fall back to trying tools in configured order
	for _, tool in ipairs(config.tools) do
		local getter = env_getters[tool]
		if getter then
			local env = getter(project_root)
			if env then
				log("Successfully got environment from " .. tool, "debug")
				return env, tool
			end
		end
	end

	return nil, nil
end

local function apply_env(env, tool)
	if not env then
		return false
	end
	if not current_env then
		current_env = {
			original = {
				VIRTUAL_ENV = vim.env.VIRTUAL_ENV,
				PATH = vim.env.PATH,
				PYTHON = vim.env.PYTHON,
			},
		}
	end
	for key, value in pairs(env) do
		vim.env[key] = value
	end

	current_env.active = env
	current_env.tool = tool
	if config.notify then
		notify("Environment activated using " .. tool .. " (" .. env.VIRTUAL_ENV .. ")")
	end
	return true
end

local function restore_env()
	if not current_env or not current_env.original then
		return
	end
	for key, value in pairs(current_env.original) do
		vim.env[key] = value
	end
	if config.notify then
		notify("Environment restored")
	end
	current_env = nil
end

function M.setup_env()
	local project_root, project_files = find_project_root()
	if not project_root then
		log("No Python project detected in current directory", "debug")
		return false
	end

	if project_envs[project_root] then
		log("Using cached environment for " .. project_root, "debug")
		return apply_env(project_envs[project_root].env, project_envs[project_root].tool)
	end

	log("Found Python project at: " .. project_root .. " (" .. table.concat(project_files, ", ") .. ")", "debug")
	local env, tool = get_project_env(project_root, project_files)
	if env then
		project_envs[project_root] = { env = env, tool = tool }
		return apply_env(env, tool)
	else
		log("Could not determine Python environment for project", "error")
		return false
	end
end

function M.get_env_info()
	if current_env and current_env.active then
		return {
			virtual_env = current_env.active.VIRTUAL_ENV,
			python = current_env.active.PYTHON,
			tool = current_env.tool,
		}
	end
	return nil
end

function M.clear_cache()
	local project_root, _ = find_project_root()
	if project_root and project_envs[project_root] then
		project_envs[project_root] = nil
		notify("Cache cleared for " .. project_root)
	else
		notify("No cache to clear for current project")
	end
end


function M.setup(user_config)
	config = vim.tbl_deep_extend("force", default_config, user_config or {})

	-- Create user commands
	vim.api.nvim_create_user_command("PythonEnvSetup", function()
		M.setup_env()
	end, { desc = "Setup Python environment for current project" })

	vim.api.nvim_create_user_command("PythonEnvRestore", function()
		restore_env()
	end, { desc = "Restore original environment" })

	vim.api.nvim_create_user_command("PythonEnvClearCache", function()
		M.clear_cache()
	end, { desc = "Clear the environment cache for the current project" })


	vim.api.nvim_create_user_command("PythonEnvInfo", function()
		local info = M.get_env_info()
		if info then
			print("Python Environment:")
			print("  Virtual Env: " .. info.virtual_env)
			print("  Python: " .. info.python)
			print("  Tool: " .. info.tool)
		else
			print("No Python environment active")
		end
	end, { desc = "Show current Python environment info" })

	-- Auto-setup on directory change
	if config.auto_setup then
		vim.api.nvim_create_autocmd({ "DirChanged", "VimEnter" }, {
			callback = function()
				M.setup_env()
			end,
			desc = "Auto-setup Python environment",
		})
	end

	log("Python environment plugin initialized", "debug")
end

return M
