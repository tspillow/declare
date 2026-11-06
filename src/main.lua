require "variables"
for _, a in ipairs(arg or {}) do
	if a == "--dry-run" or a == "-n" then
		dry_run = true
	end
end

print("Starting deployment" .. (dry_run and " (dry run)" or "") .. "...")

local ok = src.apply(desired_state, { dry_run = dry_run })

if ok then
	print("[SUCCESS] Done.")
else
	print("[FAILED] Deployment came with errors!")
	os.exit(1)
end
