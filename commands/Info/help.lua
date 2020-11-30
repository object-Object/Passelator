local discordia = require("discordia")
local commandHandler = require("commandHandler")
local utils = require("miscUtils")

local function appendSubcommands(str, indent, command)
	for subcommandString, subcommand in pairs(command.subcommands) do
		str = str..indent..subcommandString.."\n"
		str = appendSubcommands(str, indent.."  ", subcommand)
	end
	return str
end

local function showMainHelp(message, guildSettings, conn, showSubcommands)
	local fields = {}
	for _, categoryString in ipairs(commandHandler.sortedCategoryNames) do
		local category = commandHandler.sortedCommandNames[categoryString]
		if not categoryString:match("^%.") then
			local output = "```\n"
			for _, commandString in ipairs(category) do
				local command = commandHandler.commands[commandString]
				local commandSettings = commandHandler.getCommandSettings(message.guild, command, conn)
				if command.visible and commandSettings.is_enabled then
					output = output..guildSettings.prefix..commandString.."\n"
					if showSubcommands then
						output = appendSubcommands(output, "  ", command)
					end
				end
			end
			if output~="```\n" then
				output = output:gsub("\n$","").."```"
				table.insert(fields, {name = categoryString, value = output})
			end
		end
	end
	message.channel:send{
		embed = {
			title = (showSubcommands and "Help menu + subcommands" or "Help menu"),
			description = "Looking for information about the bot? Use `"..guildSettings.prefix.."about` instead.",
			fields = fields,
			color = discordia.Color.fromHex("00ff00").value,
			footer = {
				text = "Do "..guildSettings.prefix.."help [command] for more info on a command."
			}
		}
	}
end

return {
	name = "help", -- name of the command and what users type to use it
	description = "Shows the bot's help menu or information about a specific command.",
	usage = "[command]",
	visible = true, -- whether or not this command shows up in help and is togglable by users
	permissions = {}, -- required permissions to use the command
	run = function(self, message, argString, args, guildSettings, conn) -- function called when the command is used
		if argString=="" then
			-- show normal help menu
			showMainHelp(message, guildSettings, conn, false)
		else
			-- show command-specific help
			local baseCommandString = commandHandler.stripPrefix(args[1], guildSettings, message.client)
			local command = commandHandler.commands[baseCommandString]
			if command and command.visible then
				command, extra = commandHandler.subcommandFromString(command, args)
				if extra~="" then
					utils.sendEmbed(message.channel, "Subcommand `"..extra.."` not found for command `"..guildSettings.prefix..command.name.."`.", "ff0000")
				else
					commandHandler.sendCommandHelp(message.channel, guildSettings, command, conn)
				end
			else
				-- command not found
				utils.sendEmbed(message.channel, "Command `"..guildSettings.prefix..baseCommandString.."` not found.", "ff0000")
			end
		end
	end,
	onEnable = function(self, message, guildSettings) -- function called when this command is enabled, return true if enabling can proceed
		return true
	end,
	onDisable = function(self, message, guildSettings) -- function called when this command is disabled, return true if disabling can proceed
		return true
	end,
	subcommands = {

		subcommands = {
			name = "help subcommands",
			description = "Shows a list of commands with subcommands below.",
			usage = "",
			run = function(self, message, argString, args, guildSettings, conn)
				showMainHelp(message, guildSettings, conn, true)
			end,
			subcommands = {}
		}

	}
}