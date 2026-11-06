-- stock config for kissaki
-----------------------------------

--((((( syntax notes:
--(( block syntax:
-- you can use blocks these 2 ways:

-- 1: inline
--
-- what happens is that you can use them in
-- the same line without indentation:
--
-- something = {}
-- 
-- - real example:
--
-- packages = { "git", "vim", "networkmanager" },
--
-- 2: normal
-- classic traditional blocks:
--
-- something = {
-- ...
-- }
--
-- - real example:
-- packages = {
-- 	"git",
--	"vim",
--	"networkmanager"
-- }
--(( commas *IMPORTANT!!!*
-- before the end of the file, the statements and
-- declarations are defined with a comma ','
-- before the next statement:
--
-- return {
--	something = this,
-- 	anotherThing = { "thsjfkla" },
--	sdhfhlkaa = "opsec" -- HERE: no comma
-- }
--
-- if you dont put these commas, dont come at me
-- furious asking why your config can't be rebuilded!
--------------------------------------------------------------------------

return {
	-- change the hostname to whatever you want.
	hostname = 	"katana",
	-- change your timezone to the one according to your
	-- region; time and date will be correct.
	-- as an example, let's use indianapolis.
	timezone = 	"America/Indianapolis",
	-- change your locale, or basically, language and stuff.
	-- for example, lets use the industry-standard UTF-8
	-- USA locale
	locale =	"en_US.UTF-8",
	--)
	-- what is basic in every declarative distro, is that you
	-- can install packages within it;
	-- basic layout:
	-- packages = 	{ "git", "fastfetch" },
	packages = 	{},
	-- enable services, like you do with packages;
	-- basic layout:
	-- services = 	{ "NetworkManager", "powerprofilesdaemon" },
	services = {
		"NetworkManager",
		"ananicy-cpp",
	}
}
