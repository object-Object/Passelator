local rm = require("discordia-reaction-menu")
local discordia = require("discordia")
local commandHandler = require("commandHandler")

local function permissionsValue(permissions)
	if not permissions then
		return "Same as parent command"
	elseif #permissions==0 then
		return "None"
	else
		return "`"..table.concat(permissions, "`, `").."`"
	end
end

local function insertCommand(choices, command)
	if not command.isSubcommand and not command.visible then return end
	local choice = rm.Choice{
		name = (command.isSubcommand and "Subcommand: " or "").."`"..command.name:match("(%S+)$").."`",
		destination = rm.Page{
			title = "Command: `"..command.name.."`",
			choices = {
				rm.Choice{
					name = "Enable/disable",
					getValue = function(self, menu, data)
						local commandSettings = commandHandler.getCommandSettings(menu.message.guild, command, data.conn)
						return commandSettings.is_enabled and "enabled" or "disabled"
					end,
					onChoose = function(self, menu, data)
						local success, output = commandHandler.toggleCommand(menu.message.guild, command, data.conn)
						return rm.Page{
							title = "Command: `"..command.name.."` - "..(success and "Updated!" or "Failed!"),
							color = (success and "00ff00" or "ff0000"),
							description = output,
							inHistory = false
						}
					end
				},
				rm.Choice{
					name = "Change permissions",
					getValue = function(self, menu, data)
						local commandSettings = commandHandler.getCommandSettings(menu.message.guild, command, data.conn)
						return permissionsValue(commandSettings.permissions)
					end,
					onChoose = function(self, menu, data)
						local member = menu.message.guild:getMember(menu.author)
						local permissions = commandHandler.getPermissions(menu.message.guild, command, data.conn)
						local missingPermissions = commandHandler.getMissingPermissions(member, permissions)
						if #missingPermissions==0 then
							return rm.Page{
								title = "Command: `"..command.name.."`",
								getDescription = function(self, menu, data)
									return "Enter a list of new permissions for this command, case-sensitive.\n\n"..
										   "**Current permissions:** "..(#permissions>0 and "`"..table.concat(permissions, "`, `").."`" or "None")..
										   "\n**Valid permissions:** `Default` (resets permissions to bot default), "..
										   (command.isSubcommand and "`Parent` (uses permissions of parent command), " or "")..
										   "`None` (requires no permissions), `"..table.concat(commandHandler.sortedPermissionNames, "`, `").."`"
								end,
								onPrompt = function(self, menu, data, message)
									local newPermissions = {}
									local invalidPermissions = {}
									if message.content=="Default" then
										newPermissions = command.permissions
									elseif command.isSubcommand and message.content=="Parent" then
										newPermissions = nil
									elseif message.content~="None" then
										for permission in message.content:gmatch("%a+") do
											table.insert((commandHandler.validPermissions[permission] and newPermissions or invalidPermissions), permission)
										end
										if #invalidPermissions>0 then
											return rm.Page{
												title = "Command: `"..command.name.."` - Invalid value!",
												description = "The following inputted permissions were not valid: `"..table.concat(invalidPermissions, "`, `").."`",
												color = "ff0000",
												choices = {rm.Choice{
													name = "Try again",
													destination = self
												}},
												inHistory = false
											}
										elseif #newPermissions==0 then
											return rm.Page{
												title = "Command: `"..command.name.."` - Invalid value!",
												description = "No permissions were entered.",
												color = "ff0000",
												choices = {rm.Choice{
													name = "Try again",
													destination = self
												}},
												inHistory = false
											}
										end
									end
									local commandSettings = commandHandler.getCommandSettings(menu.message.guild, command, data.conn)
									if commandSettings.permissions==newPermissions then
										return rm.Page{
											title = "Command: `"..command.name.."` - Invalid value!",
											description = "The command already has the entered permissions.",
											color = "ff0000",
											choices = {rm.Choice{
												name = "Try again",
												destination = self
											}},
											inHistory = false
										}
									end
									commandHandler.setCommandPermissions(message.guild, command, data.conn, newPermissions)
									return rm.Page{
										title = "Command: `"..command.name.."` - Updated!",
										description = "Permissions updated. New permissions: "..permissionsValue(newPermissions),
										color = "00ff00",
										inHistory = false
									}
								end
							}
						else
							return rm.Page{
								title = "Command: `"..command.name.."` - Missing permissions!",
								description = "To change a command's permissions, you must first have the permissions it currently requires.\n\n"..
											  "**Missing permissions:** `"..table.concat(missingPermissions, "`, `").."`",
								color = "ff0000",
								choices = {rm.Choice{
									name = "Try again",
									destination = self
								}},
								inHistory = false
							}
						end
					end
				}
			}
		}
	}
	for _, subcommand in pairs(command.subcommands) do
		insertCommand(choice.destination.choices, subcommand)
	end
	table.insert(choices, choice)
end

local menu
commandHandler.emitter:once("onLoad", function() -- wait until all of the commands have been loaded
	local choices = {}
	local commandNames = table.keys(commandHandler.commands) -- need to do this because commandHandler.sortedCommandNames is by category
	table.sort(commandNames)
	for _, commandString in ipairs(commandNames) do
		insertCommand(choices, commandHandler.commands[commandString])
	end
	menu = rm.Menu{
		startPage = rm.paginateChoices(choices, "Commands", "Select a command to enable it, disable it, or modify its permissions."),
		timeout = 300000
	}
end)

return {
	name = "commands",
	description = "Opens a reaction menu to enable, disable, or modify permissions of commands in this server.",
	usage = "",
	visible = true,
	permissions = {"administrator"},
	run = function(self, message, argString, args, guildSettings, conn)
		rm.send(message.channel, message.author, menu, {guildSettings=guildSettings, conn=conn})
	end,
	onEnable = function(self, message, guildSettings)
		return true
	end,
	onDisable = function(self, message, guildSettings)
		return true
	end,
	subcommands = {}
}