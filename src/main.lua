local engine = dofile("/usr/lib/kat/engine.lua")

local desired_state = dofile("/katana/declare/config.lua")

print("Starting deployment...")
engine.apply_packages(desired_state.packages or {})
engine.apply_services(desired_state.services or {})
print("[SUCCESS] Done.")
