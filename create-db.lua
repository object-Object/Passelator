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
	delete_command_messages BOOLEAN DEFAULT 0 NOT NULL CHECK (delete_command_messages IN (0,1)),
	games_category_id TEXT,
	games_channel_id TEXT,
	next_game_num REAL DEFAULT 1
);
]])
conn:exec([[
CREATE TABLE IF NOT EXISTS ping_cooldowns (
	guild_id TEXT PRIMARY KEY,
	end_timestamp REAL,
	FOREIGN KEY (guild_id) REFERENCES guild_settings(guild_id)
);
]])
conn:exec([[
CREATE TABLE IF NOT EXISTS games (
	game_num REAL,
	name TEXT,
	author_id TEXT,
	guild_id TEXT,
	message_id TEXT,
	voice_channel_id TEXT,
	voice_channel_invite TEXT,
	role_id TEXT,
	game_code TEXT,
	PRIMARY KEY (game_num, guild_id),
	FOREIGN KEY (guild_id) REFERENCES guild_settings(guild_id)
);
]])
print("Done.")