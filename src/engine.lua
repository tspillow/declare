local engine = {}

local function run_cmd(cmd)
	local handle = io.popen(cmd .. " 2>&1; echo '|||'$?")
	if not handle then
		return false, "[ERROR] Failed to execute command"
	end

	local result = handle:read("*a")
	handle:close()

	local output, exit_code = result:match("(.*)|||(%d+)\n")
	return tonumber(exit_code) == 0, output or result
end

local function is_package_installed(pkg)
	local success, _ = run_cmd(
		"/usr/bin/pacman -Qi" .. pkg
	)

	return success
end

local function is_service_enabled(service)
	local success, _ = run_cmd(
		"systemctl is-enabled" .. service
	)

	return success
end

function engine.apply_packages(desired_packages)
	print("[...] Enforcing packages")

	for _, pkg in ipairs(desired_packages) do
		if is_package_installed(pkg) then
			print("[OK, BUT] " .. pkg .. " is already installed.")
		else
			print("[+] Installing package " .. pkg .. "...")

			local success, err = run_cmd(
				"sudo pacman -S --noconfirm " .. pkg
			)

			if not success then
				print("[ERROR] Failed to install package "
					.. pkg .. ": " .. tostring(err))
			end
		end
	end
end

function engine.apply_services(desired_services)
	print("[...] Enforcing services")

	for service, state in pairs(desired_services) do
		local service_script = "/usr/lib/systemd/system/" .. service

		if state == "enabled" then
			print("[OK] Service '" .. service .. "' is enabled.")
		end
	end
end

return engine
