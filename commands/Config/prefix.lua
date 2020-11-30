local utils = require("miscUtils")
local commandHandler = require("commandHandler")
local discordia = require("discordia")
local options = discordia.storage.options

return {
	name = "prefix",
	description = "Displays the bot's current prefix in this server.",
	usage = "",
	visible = true,
	botGuildPermissions = {},
	botChannelPermissions = {},
	permissions = {},
	run = function(self, message, argString, args, guildSettings, conn)
		utils.sendEmbed(message.channel, "The current command prefix is `"..guildSettings.prefix.."`.", "00ff00", "To change the command prefix, use: "..guildSettings.prefix.."prefix set <new prefix>")
	end,
	onEnable = function(self, guildSettings, conn)
		return true
	end,
	onDisable = function(self, guildSettings, conn)
		return true
	end,
	subcommands = {

		set = {
			name = "prefix set",
			description = "Sets the bot's prefix in this server.",
			usage = "<new prefix>",
			botGuildPermissions = {},
			botChannelPermissions = {},
			permissions = {"administrator"},
			run = function(self, message, argString, args, guildSettings, conn)
				if argString=="" then
					commandHandler.sendUsage(message.channel, guildSettings, self)
					return
				end
				local newPrefix = argString:gsub("%`(.+)%`","%1")
				if guildSettings.prefix==newPrefix then
					utils.sendEmbed(message.channel, "The command prefix is already `"..newPrefix.."`.","ff0000")
					return
				end
				local stmt = conn:prepare("UPDATE guild_settings SET prefix = ? WHERE guild_id = ?;")
				stmt:reset():bind(newPrefix, message.guild.id):step()
				stmt:close()
				utils.sendEmbed(message.channel, "The command prefix has been changed from `"..guildSettings.prefix.."` to `"..newPrefix.."`.", "00ff00")
			end,
			subcommands = {}
		},

		reset = {
			name = "prefix reset",
			description = "Resets the bot's prefix in this server to the default.",
			usage = "",
			botGuildPermissions = {},
			botChannelPermissions = {},
			permissions = {"administrator"},
			run = function(self, message, argString, args, guildSettings, conn)
				if guildSettings.prefix==options.defaultPrefix then
					utils.sendEmbed(message.channel, "The command prefix is already `"..options.defaultPrefix.."`.","ff0000")
					return
				end
				local stmt = conn:prepare("UPDATE guild_settings SET prefix = ? WHERE guild_id = ?;")
				stmt:reset():bind(options.defaultPrefix, message.guild.id):step()
				stmt:close()
				utils.sendEmbed(message.channel, "The command prefix has been changed from `"..guildSettings.prefix.."` back to the default, `"..options.defaultPrefix.."`.", "00ff00")
			end,
			subcommands = {}
		}

	}
}