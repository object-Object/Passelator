local sql = require("sqlite3")
local conn = sql.open("bot.db")
local options = require("options")

print("Creating database...")
conn:exec([[
CREATE TABLE IF NOT EXISTS guild_settings (
	guild_id TEXT PRIMARY KEY,
	persistent_roles TEXT DEFAULT "{}",
	disabled_commands TEXT DEFAULT "{}",
	disabled_modules TEXT DEFAULT "{}",
	command_permissions TEXT DEFAULT "{}",
	prefix TEXT DEFAULT "]]..options.defaultPrefix..[[",
	mass_ping_cooldown REAL DEFAULT ]]..options.defaultMassPingCooldown..[[,
	delete_command_messages BOOLEAN DEFAULT 0 NOT NULL CHECK (delete_command_messages IN (0,1))
);
]])
conn:exec([[
CREATE TABLE IF NOT EXISTS ping_cooldowns (
	guild_id TEXT PRIMARY KEY,
	end_timestamp REAL,
	FOREIGN KEY (guild_id) REFERENCES guild_settings(guild_id)
);
]])
print("Done.")