-- Welcome to Kissaki.
-- Kissaki is Katana Linux's official declarative system.
---(
-- author: tspillow
----------------------------------
------ requires
require "variables"
------ some definitions
kissaki.version = "0.4"
kissaki.dry_run = false
local errors = 0 
local function quote(s)
  return "'" .. (tostring(s):gsub("'', "'\\''")) .. "'"
end
--------------------------------------------------------------------------------------------------
local function run_cmd(cmd)
	local handle = io.popen(cmd .. " 2>&1; echo '|||'$?")
	if not handle then
		return false, "failed to execute command"
	end

	local result = handle:read("*a")
	handle:close()

	local output, exit_code = result:match("^(.*)|||(%d+)%s*$")
	return tonumber(exit_code) == 0, output or result
end

local function act(cmd)
	if engine.dry_run then
		print("[DRY] " .. cmd)
		return true, ""
	end
	return run_cmd(cmd)
end

local function fail(msg)
	errors = errors + 1
	print("[ERROR] " .. msg)
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_list(t)
	return type(t) == "table" and (#t > 0 or next(t) == nil)
end

local function expect(name, value, kind)
	if value == nil then
		return false
	end
	if kind == "list" then
		if is_list(value) then
			return true
		end
		fail("'" .. name .. "' must be a list, e.g. { \"a\", \"b\" }")
		return false
	end
	if type(value) ~= kind then
		fail("'" .. name .. "' must be a " .. kind)
		return false
	end
	return true
end

local function write_root_file(path, content, mode)
	if engine.dry_run then
		print("[DRY] write " .. path)
		return true
	end

	local tmp = os.tmpname()
	local f = io.open(tmp, "w")
	if not f then
		return false, "cannot create temp file"
	end
	f:write(content)
	f:close()

	local ok, out = run_cmd(
		"sudo install -D -m " .. (mode or "644") .. " "
			.. quote(tmp) .. " " .. quote(path)
	)
	os.remove(tmp)
	return ok, out
end

local function unit_name(service)
	if service:find(".", 1, true) then
		return service
	end
	return service .. ".service"
end

local function is_package_installed(pkg)
	local ok = run_cmd("/usr/bin/pacman -Qq " .. quote(pkg))
	return ok
end

local function is_service_enabled(service)
	local ok = run_cmd("systemctl is-enabled --quiet " .. quote(unit_name(service)))
	return ok
end

local function is_service_active(service)
	local ok = run_cmd("systemctl is-active --quiet " .. quote(unit_name(service)))
	return ok
end

local function user_exists(name)
	local ok = run_cmd("id -u " .. quote(name))
	return ok
end

function engine.apply_hostname(name)
	if not expect("hostname", name, "string") then
		return
	end
	print("[...] Enforcing hostname")

	if #name > 63 or not name:match("^[%w][%w%-]*$") then
		fail("Invalid hostname: " .. name)
		return
	end

	local current = trim(read_file("/etc/hostname") or "")
	if current == name then
		print("[OK] /etc/hostname is already '" .. name .. "'.")
	else
		print("[+] Setting /etc/hostname to '" .. name .. "'")
		local ok, err = write_root_file("/etc/hostname", name .. "\n", "644")
		if not ok then
			fail("Could not write /etc/hostname: " .. tostring(err))
			return
		end
	end

	local live = trim(read_file("/proc/sys/kernel/hostname") or "")
	if live ~= name then
		local ok, err = act("echo " .. quote(name) .. " | sudo tee /proc/sys/kernel/hostname")
		if not ok then
			print("[WARN] Could not set live hostname: " .. tostring(err))
		end
	end

	local hosts = read_file("/etc/hosts") or ""
	local kept = {}
	for line in hosts:gmatch("[^\n]*\n?") do
		if line ~= "" and not line:match("^127%.0%.1%.1") then
			kept[#kept + 1] = line
		end
	end
	local body = table.concat(kept)
	if body ~= "" and body:sub(-1) ~= "\n" then
		body = body .. "\n"
	end
	body = body .. "127.0.1.1\t" .. name .. "\n"

	if body ~= hosts then
		local ok, err = write_root_file("/etc/hosts", body, "644")
		if not ok then
			fail("Could not update /etc/hosts: " .. tostring(err))
		end
	end
end

function engine.apply_timezone(tz)
	if not expect("timezone", tz, "string") then
		return
	end
	print("[...] Enforcing timezone")

	local ok, current = run_cmd("readlink -f /etc/localtime")
	if ok and trim(current) == "/usr/share/zoneinfo/" .. tz then
		print("[OK] Timezone is already " .. tz .. ".")
		return
	end

	print("[+] Setting timezone to " .. tz)
	local done, err = act(
		"sudo ln -sf " .. quote("/usr/share/zoneinfo/" .. tz) .. " /etc/localtime"
	)
	if not done then
		fail("Failed to set timezone: " .. tostring(err))
	end
end

function engine.apply_locale(locale)
	if not expect("locale", locale, "string") then
		return
	end
	print("[...] Enforcing locale")

	local conf = read_file("/etc/locale.conf") or ""
	if trim(conf) == "LANG=" .. locale then
		print("[OK] Locale is already " .. locale .. ".")
		return
	end

	local escaped = locale:gsub("%.", "\\.")
	local ok, err = act(
		"sudo sed -i 's/^#\\s*\\(" .. escaped .. " \\)/\\1/' /etc/locale.gen"
	)
	if ok then
		ok, err = act("sudo locale-gen")
	end
	if ok then
		ok, err = write_root_file("/etc/locale.conf", "LANG=" .. locale .. "\n", "644")
	end
	if not ok then
		fail("Failed to set locale: " .. tostring(err))
	end
end

function engine.apply_keymap(keymap)
	if not expect("keymap", keymap, "string") then
		return
	end
	print("[...] Enforcing console keymap")

	local conf = read_file("/etc/vconsole.conf") or ""
	if trim(conf) == "KEYMAP=" .. keymap then
		print("[OK] Keymap is already " .. keymap .. ".")
		return
	end

	local ok, err = write_root_file("/etc/vconsole.conf", "KEYMAP=" .. keymap .. "\n", "644")
	if not ok then
		fail("Failed to set keymap: " .. tostring(err))
	end
end

function engine.apply_packages(desired_packages)
	if not expect("packages", desired_packages, "list") then
		return
	end
	print("[...] Enforcing packages")

	local missing = {}
	for _, pkg in ipairs(desired_packages) do
		if is_package_installed(pkg) then
			print("[OK] " .. pkg .. " is already installed.")
		else
			missing[#missing + 1] = quote(pkg)
		end
	end

	if #missing > 0 then
		print("[+] Installing " .. #missing .. " package(s)...")
		local ok, err = act(
			"sudo pacman -S --needed --noconfirm " .. table.concat(missing, " ")
		)
		if not ok then
			fail("pacman failed: " .. tostring(err))
		end
	end
end

function engine.apply_aur(desired_aur)
	if not expect("aur", desired_aur, "list") then
		return
	end
	print("[...] Enforcing AUR packages")

	local missing = {}
	for _, pkg in ipairs(desired_aur) do
		if is_package_installed(pkg) then
			print("[OK] " .. pkg .. " is already installed.")
		else
			missing[#missing + 1] = quote(pkg)
		end
	end

	if #missing > 0 then
		print("[+] Installing " .. #missing .. " AUR package(s)...")
		local ok, err = act(
			"yay -S --needed --noconfirm " .. table.concat(missing, " ")
		)
		if not ok then
			fail("yay failed: " .. tostring(err))
		end
	end
end

function engine.apply_absent_packages(unwanted)
	if not expect("packages_absent", unwanted, "list") then
		return
	end
	print("[...] Removing unwanted packages")

	for _, pkg in ipairs(unwanted) do
		if is_package_installed(pkg) then
			print("[-] Removing " .. pkg)
			local ok, err = act("sudo pacman -Rns --noconfirm " .. quote(pkg))
			if not ok then
				fail("Failed to remove " .. pkg .. ": " .. tostring(err))
			end
		end
	end
end

function engine.apply_users(desired_users)
	if not expect("users", desired_users, "table") then
		return
	end
	print("[...] Enforcing users")

	for name, spec in pairs(desired_users) do
		if type(name) ~= "string" then
			fail("users must be written as name = ..., e.g. alice = { \"wheel\" }")
		else
			if spec == true then
				spec = {}
			elseif type(spec) == "table" and type(spec[1]) == "string" then
				spec = { groups = spec }
			elseif type(spec) ~= "table" then
				fail("Invalid spec for user " .. name)
				spec = nil
			end

			if spec then
				local groups = table.concat(spec.groups or {}, ",")
				local shell = spec.shell or "/bin/bash"

				if not user_exists(name) then
					print("[+] Creating user " .. name)
					local cmd = "sudo useradd -m -s " .. quote(shell)
					if groups ~= "" then
						cmd = cmd .. " -G " .. quote(groups)
					end
					local ok, err = act(cmd .. " " .. quote(name))
					if not ok then
						fail("Failed to create user " .. name .. ": " .. tostring(err))
					end
				elseif groups ~= "" then
					local ok, err = act(
						"sudo usermod -aG " .. quote(groups) .. " " .. quote(name)
					)
					if ok then
						print("[OK] User '" .. name .. "' present, groups ensured.")
					else
						fail("Failed to update groups for " .. name .. ": " .. tostring(err))
					end
				end
			end
		end
	end
end

function engine.apply_files(desired_files)
	if not expect("files", desired_files, "table") then
		return
	end
	print("[...] Enforcing files")

	for path, spec in pairs(desired_files) do
		if type(spec) == "string" then
			spec = { content = spec }
		end

		if type(path) ~= "string" or type(spec) ~= "table"
			or type(spec.content) ~= "string" then
			fail("Invalid file entry: " .. tostring(path))
		elseif read_file(path) == spec.content then
			print("[OK] " .. path .. " is up to date.")
		else
			print("[+] Writing " .. path)
			local ok, err = write_root_file(path, spec.content, spec.mode)
			if not ok then
				fail("Failed to write " .. path .. ": " .. tostring(err))
			end
		end
	end
end

function engine.apply_services(desired_services)
	if not expect("services", desired_services, "table") then
		return
	end
	print("[...] Enforcing services")

	for key, value in pairs(desired_services) do
		local service, state = key, value
		if type(key) == "number" then
			service, state = value, "enabled"
		elseif value == true then
			state = "enabled"
		elseif value == false then
			state = "disabled"
		end

		if type(service) ~= "string" then
			fail("Invalid service entry: " .. tostring(service))
		else
			local unit = quote(unit_name(service))

			if state == "enabled" then
				if not is_service_enabled(service) then
					print("[+] Enabling " .. service)
					local ok, err = act("sudo systemctl enable --now " .. unit)
					if not ok then
						fail("Failed to enable " .. service .. ": " .. tostring(err))
					end
				elseif not is_service_active(service) then
					print("[+] Starting " .. service)
					local ok, err = act("sudo systemctl start " .. unit)
					if not ok then
						fail("Failed to start " .. service .. ": " .. tostring(err))
					end
				else
					print("[OK] Service '" .. service .. "' is enabled and running.")
				end
			elseif state == "disabled" then
				if is_service_enabled(service) or is_service_active(service) then
					print("[-] Disabling " .. service)
					local ok, err = act("sudo systemctl disable --now " .. unit)
					if not ok then
						fail("Failed to disable " .. service .. ": " .. tostring(err))
					end
				else
					print("[OK] Service '" .. service .. "' is already disabled.")
				end
			else
				fail("Unknown state '" .. tostring(state) .. "' for service " .. service)
			end
		end
	end
end

local steps = {
	{ "hostname",        engine.apply_hostname },
	{ "timezone",        engine.apply_timezone },
	{ "locale",          engine.apply_locale },
	{ "keymap",          engine.apply_keymap },
	{ "packages",        engine.apply_packages },
	{ "aur",             engine.apply_aur },
	{ "packages_absent", engine.apply_absent_packages },
	{ "users",           engine.apply_users },
	{ "files",           engine.apply_files },
	{ "services",        engine.apply_services },
}

function engine.apply(config, opts)
	engine.dry_run = (opts and opts.dry_run) or false
	errors = 0

	if type(config) ~= "table" then
		fail("config must return a table")
		return false
	end

	for _, step in ipairs(steps) do
		local key, fn = step[1], step[2]
		-- one broken section must not stop the rest
		local ok, err = pcall(fn, config[key])
		if not ok then
			fail("'" .. key .. "' crashed: " .. tostring(err))
		end
	end

	if errors > 0 then
		print("[DONE] Finished with " .. errors .. " error(s).")
	else
		print("[DONE] System matches the desired state.")
	end
	return errors == 0
end
    
    
