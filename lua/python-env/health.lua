-- Health check for python-env plugin
local M = {}

local health = vim.health or require("health")

function M.check()
	health.start("python-env.nvim")

	local ok, python_env = pcall(require, "python-env")
	if not ok then
		health.error("python-env plugin not found")
		return
	end
	health.ok("python-env plugin loaded successfully")

	local tools = { "uv", "poetry" }
	local found_tools = {}
	for _, tool in ipairs(tools) do
		local handle = io.popen("which " .. tool .. " 2>/dev/null")
		if handle then
			local result = handle:read("*a")
			handle:close()
			if result and result ~= "" then
				table.insert(found_tools, tool)
				health.ok(tool .. " found: " .. result:gsub("%s+$", ""))
			else
				health.warn(tool .. " not found in PATH")
			end
		else
			health.warn("Could not check for " .. tool)
		end
	end

	if #found_tools == 0 then
		health.error("No supported Python environment tools found (uv, poetry)")
		health.info("Install at least one of: uv or poetry")
	else
		health.ok("Found " .. #found_tools .. " supported tool(s): " .. table.concat(found_tools, ", "))
	end

	local project_files = {
		"pyproject.toml",
		"poetry.lock",
		"uv.lock",
	}

	local found_project_files = {}
	for _, file in ipairs(project_files) do
		if vim.fn.filereadable(file) == 1 then
			table.insert(found_project_files, file)
		end
	end

	if #found_project_files > 0 then
		health.ok("Python project detected: " .. table.concat(found_project_files, ", "))

		local env_info = python_env.get_env_info()
		if env_info then
			health.ok("Environment active:")
			health.info("  Virtual Env: " .. env_info.virtual_env)
			health.info("  Python: " .. env_info.python)
			health.info("  Tool: " .. env_info.tool)
		else
			health.warn("No environment currently active")
			health.info("Try running :PythonEnvSetup to activate environment")
		end
	else
		health.info("No Python project files found in current directory")
	end
end

return M

