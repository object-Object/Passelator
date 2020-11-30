local sql = require("sqlite3")
local conn = sql.open("bot.db")
local options = require("options")

print("Creating database...")
conn:exec([[
CREATE TABLE IF NOT EXISTS guild_settings (
	guild_id TEXT PRIMARY KEY,
	prefix TEXT,
	mass_ping_cooldown REAL,
	delete_command_messages BOOLEAN DEFAULT 0 NOT NULL CHECK (delete_command_messages IN (0,1)),
	delete_group_messages BOOLEAN DEFAULT 0 NOT NULL CHECK (delete_group_messages IN (0,1)),
	can_add_remove_to_locked BOOLEAN DEFAULT 1 NOT NULL CHECK (can_add_remove_to_locked IN (0,1)),
	can_leave_locked BOOLEAN DEFAULT 1 NOT NULL CHECK (can_leave_locked IN (0,1)),
	give_back_roles BOOLEAN DEFAULT 1 NOT NULL CHECK (give_back_roles IN (0,1)),
	group_category_id TEXT,
	group_channel_id TEXT,
	next_group_num REAL DEFAULT 1
);
]])
conn:exec([[
CREATE TABLE IF NOT EXISTS commands (
	guild_id TEXT,
	command TEXT,
	is_enabled BOOLEAN DEFAULT 1 NOT NULL CHECK (is_enabled IN (0,1)),
	permissions TEXT,
	UNIQUE (guild_id, command),
	FOREIGN KEY (guild_id) REFERENCES guild_settings(guild_id)
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
CREATE TABLE IF NOT EXISTS groups (
	group_num REAL,
	name TEXT,
	creator_id TEXT,
	guild_id TEXT,
	message_id TEXT,
	voice_channel_id TEXT,
	voice_channel_invite TEXT,
	role_id TEXT,
	code TEXT,
	date_time TEXT,
	is_locked BOOLEAN DEFAULT 0 NOT NULL CHECK (is_locked IN (0,1)),
	UNIQUE (group_num, guild_id),
	FOREIGN KEY (guild_id) REFERENCES guild_settings(guild_id)
);
]])
conn:exec([[
CREATE TABLE IF NOT EXISTS user_roles (
	guild_id TEXT,
	user_id TEXT,
	role_id TEXT,
	user_in_guild BOOLEAN DEFAULT 1 NOT NULL CHECK (user_in_guild IN (0,1)),
	UNIQUE (guild_id, user_id, role_id),
	FOREIGN KEY (guild_id) REFERENCES guild_settings(guild_id)
);
]])
print("Done.")
return conn