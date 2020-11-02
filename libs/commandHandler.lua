local fs = require("fs")
local utils = require("miscUtils")
local json = require("json")
local discordia = require("discordia")

local function applySubcommandReferences(command, baseCommand)
	for _, subcommand in pairs(command.subcommands) do
		subcommand.parentCommand = command
		subcommand.baseCommand = baseCommand
		subcommand.isSubcommand = true
		applySubcommandReferences(subcommand, baseCommand)
	end
end

local commandHandler = {}

commandHandler.commands = {}				-- keys: commandString, values: command table
commandHandler.tree = {}					-- table for each category, holding commands in same format as commandHandler.commands
commandHandler.sortedCategoryNames = {}		-- values: category names, sorted alphabetically
commandHandler.sortedCommandNames = {}		-- table for each category, values: command names, sorted alphabetically
commandHandler.sortedPermissionNames = {}	-- values: permission enums, sorted alphabetically

commandHandler.customPermissions = {
	botOwner = function(member)
		return member.user==member.client.owner
	end
}

commandHandler.load = function()
	for category, filetype in fs.scandirSync("commands") do
		assert(filetype=="directory", "Non-directory file '"..category.."' in commands/ directory")
		if not commandHandler.tree[category] then
			commandHandler.tree[category] = {}
			commandHandler.sortedCommandNames[category] = {}
			table.insert(commandHandler.sortedCategoryNames, category)
		end
		for _, commandFilename in ipairs(fs.readdirSync("commands/"..category)) do
			if commandFilename:match("%.lua$") then
				local command = require("../commands/"..category.."/"..commandFilename)
				applySubcommandReferences(command, command)
				command.parentCommand = command
				command.baseCommand = command
				command.isSubcommand = false
				command.category = category
				commandHandler.commands[command.name] = command
				commandHandler.tree[category][command.name] = command
				table.insert(commandHandler.sortedCommandNames[category], command.name)
			end
		end
	end
	table.sort(commandHandler.sortedCommandNames)
	commandHandler.sortedPermissionNames = table.keys(discordia.enums.permission)
	table.sort(commandHandler.sortedPermissionNames)
end

commandHandler.stripPrefix = function(str, guildSettings, client)
	return str:gsub("^"..utils.escapePatterns(guildSettings.prefix),""):gsub("^%<%@%!?"..client.user.id.."%>%s+","")
end

-- input can be string.split-ed table (for efficiency, if you've already split it) or string
-- string should contain command name
commandHandler.subcommandFromString = function(command, input)
	local inputType = type(input)
	assert(inputType=="table" or inputType=="string", "Expected table or string for argument #1, got "..inputType)
	local splitStr = inputType=="table" and input or input:split("%s+")
	table.remove(splitStr, 1) -- remove the base command name from splitStr
	local output = command
	if #splitStr>0 then
		local currentCommand = command
		local subcommand
		repeat
			subcommand = currentCommand.subcommands[splitStr[1]]
			if subcommand then
				currentCommand = subcommand
				table.remove(splitStr, 1)
			end
		until not subcommand or #splitStr==0
		output = subcommand or currentCommand
	end
	return output, table.concat(splitStr, " "), splitStr
end

commandHandler.sendUsage = function(channel, guildSettings, command)
	local usage = command.usage~="" and " "..command.usage or ""
	return utils.sendEmbed(channel, "Usage: "..usage, "ff0000", "Angled brackets represent required arguments. Square brackets represent optional arguments. Do not include the brackets in the command. All values are case sensitive.")
end

commandHandler.getPermissions = function(guildSettings, command)
	local permissions = guildSettings.command_permissions[command.name]
		or command.permissions
		or guildSettings.command_permissions[command.baseCommand.name]
		or command.baseCommand.permissions

	return permissions
end

commandHandler.getPermissionsString = function(guildSettings, command)
	local permissions = commandHandler.getPermissions(guildSettings, command)
	return #permissions>0 and "`"..table.concat(permissions, ", ").."`" or "None"
end

commandHandler.sendCommandHelp = function(channel, guildSettings, command)
	local baseCommand = command.baseCommand
	if guildSettings.disabled_commands[baseCommand.name] then
		channel:send{
			embed = {
				title = guildSettings.prefix..command.name,
				description = "`"..guildSettings.prefix..baseCommand.name.."` is disabled in this server.",
				color = discordia.Color.fromHex("ff0000").value
			}
		}
	else
		local subcommandsKeys = table.keys(command.subcommands)
		table.sort(subcommandsKeys)

		local permissionsString = commandHandler.getPermissionsString(guildSettings, command)

		local subcommandsString = #subcommandsKeys>0 and "`"..table.concat(subcommandsKeys, "`, `").."`" or "None"
		local usage = command.usage~="" and " "..command.usage or ""
		channel:send{
			embed = {
				title = guildSettings.prefix..command.name,
				description = command.description:gsub("%&prefix%;", guildSettings.prefix),
				fields = {
					{name = "Category", value = baseCommand.category},
					{name = "Required permissions", value = permissionsString},
					{name = "Subcommands", value = subcommandsString},
					{name = "Usage", value = "`"..guildSettings.prefix..command.name..usage.."`"}
				},
				color = discordia.Color.fromHex("00ff00").value,
				footer = {
					text = "Angled brackets represent required arguments. Square brackets represent optional arguments. Do not include the brackets in the command. All values are case sensitive."
				}
			}
		}
	end
end

commandHandler.sendPermissionError = function(channel, commandString, missingPermissions)
	return utils.sendEmbed(channel, "You may not use this command because you are missing the following required permission"..utils.s(#missingPermissions)..": "..table.concat(missingPermissions, ", "), "ff0000")
end

commandHandler.enable = function(commandString, message, guildSettings, conn)
	if not commandHandler.commands[commandString]:onEnable(guildSettings, conn) then
		return false
	end
	guildSettings.disabled_commands[commandString] = nil
	local encodedSetting = json.encode(guildSettings.disabled_commands)
	local stmt = conn:prepare("UPDATE guild_settings SET disabled_commands = ? WHERE guild_id = ?;")
	stmt:reset():bind(encodedSetting, message.guild.id):step()
	stmt:close()
	return true
end

commandHandler.disable = function(commandString, message, guildSettings, conn)
	if not commandHandler.commands[commandString]:onDisable(guildSettings, conn) then
		return false
	end
	guildSettings.disabled_commands[commandString] = true
	local encodedSetting = json.encode(guildSettings.disabled_commands)
	local stmt = conn:prepare("UPDATE guild_settings SET disabled_commands = ? WHERE guild_id = ?;")
	stmt:reset():bind(encodedSetting, message.guild.id):step()
	stmt:close()
	return true
end

commandHandler.toggle = function(command, guildSettings, conn)
	local success, output
	if guildSettings.disabled_commands[command.name] then
		success, output = command:onEnable(guildSettings, conn)
	else
		success, output = command:onDisable(guildSettings, conn)
	end

	if not success then
		return false, output
	end

	guildSettings.disabled_commands[command.name] = not guildSettings.disabled_commands[command.name] or nil

	local encodedSetting = json.encode(guildSettings.disabled_commands)
	local stmt = conn:prepare("UPDATE guild_settings SET disabled_commands = ? WHERE guild_id = ?;")
	stmt:reset():bind(encodedSetting, guildSettings.guild_id):step()
	stmt:close()

	return true, (output or (guildSettings.disabled_commands[command.name] and "The command was successfully disabled." or "The command was successfully enabled."))
end

commandHandler.getMissingPermissions = function(member, permissions)
	local missingPermissions = {}
	for _,permission in pairs(permissions) do
		if permission:match("^yot%.") then
			if not commandHandler.customPermissions[permission:match("^yot%.(.+)")](member) then
				table.insert(missingPermissions, permission)
			end
		else
			if not member:hasPermission(permission) then
				table.insert(missingPermissions, permission)
			end
		end
	end
	return missingPermissions
end

commandHandler.doCommands = function(message, guildSettings, conn)
	local content = commandHandler.stripPrefix(message.content, guildSettings, message.client)
	local commandString = content:match("^(%S+)")
	local command = commandHandler.commands[commandString]
	if message.content~=content and command and not guildSettings.disabled_commands[commandString] then
		local argString, args
		if command.subcommands~={} then
			command, argString, args = commandHandler.subcommandFromString(command, content)
		else
			argString = content:gsub("^"..commandString.."%s*","")
			args = argString:split("%s")
		end
		local permissions = commandHandler.getPermissions(guildSettings, command)
		local missingPermissions = commandHandler.getMissingPermissions(message.member, permissions)
		if #missingPermissions==0 then
			command:run(message, argString, args, guildSettings, conn)
		else
			commandHandler.sendPermissionError(message.channel, commandString, missingPermissions)
		end
		if guildSettings.delete_command_messages then message:delete() end
	end
end

return commandHandler