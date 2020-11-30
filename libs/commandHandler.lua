local fs = require("fs")
local utils = require("miscUtils")
local json = require("json")
local discordia = require("discordia")

local function getGuildsMissingCommand(command, conn)
	local resultset = conn:exec([[
		SELECT guild_settings.guild_id AS guild_id
		FROM guild_settings
		WHERE NOT EXISTS(
			SELECT *
			FROM commands
			WHERE guild_settings.guild_id = commands.guild_id AND commands.command = ']]..command.name..[['
		);
	]])
	return resultset and resultset.guild_id or {}
end

local function updateSubcommands(command, baseCommand, conn, stmt)
	for _, subcommand in pairs(command.subcommands) do
		if subcommand.isDefaultDisabled==nil then
			subcommand.isDefaultDisabled = command.isDefaultDisabled
		end
		subcommand.parentCommand = command
		subcommand.baseCommand = baseCommand
		subcommand.isSubcommand = true
		local guildIds = getGuildsMissingCommand(subcommand, conn)
		for _, guildId in pairs(guildIds) do
			stmt:reset():bind(guildId, subcommand.name, (not subcommand.isDefaultDisabled and 1 or 0), json.encode(subcommand.permissions)):step()
		end
		updateSubcommands(subcommand, baseCommand, conn, stmt)
	end
end

local commandHandler = {}

commandHandler.commands = {}				 -- keys: commandString, values: command table
commandHandler.tree = {}					 -- table for each category, holding commands in same format as commandHandler.commands
commandHandler.sortedCategoryNames = {}		 -- values: category names, sorted alphabetically
commandHandler.sortedCommandNames = {}		 -- table for each category, values: command names, sorted alphabetically
commandHandler.validPermissions = {}         -- keys: permission enums, values: true
commandHandler.sortedPermissionNames = {}	 -- values: permission enums, sorted alphabetically
commandHandler.emitter = discordia.Emitter() -- used for onLoad event

commandHandler.customPermissions = {
	botOwner = function(member)
		return member.user==member.client.owner
	end
}

commandHandler.load = function(conn)
	local stmt = conn:prepare("INSERT INTO commands (guild_id, command, is_enabled, permissions) VALUES (?, ?, ?, ?);")
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
				assert(type(command.subcommands)=="table", "Command "..category.."/"..command.name.." missing subcommands")
				updateSubcommands(command, command, conn, stmt)
				command.parentCommand = command
				command.baseCommand = command
				command.isSubcommand = false
				command.category = category
				commandHandler.commands[command.name] = command
				commandHandler.tree[category][command.name] = command
				table.insert(commandHandler.sortedCommandNames[category], command.name)
				local guildIds = getGuildsMissingCommand(command, conn)
				for _, guildId in pairs(guildIds) do
					stmt:reset():bind(guildId, command.name, (not command.isDefaultDisabled and 1 or 0), json.encode(command.permissions)):step()
				end
			end
		end
	end
	stmt:close()
	table.sort(commandHandler.sortedCommandNames)
	for permission, _ in pairs(discordia.enums.permission) do
		table.insert(commandHandler.sortedPermissionNames, permission)
		commandHandler.validPermissions[permission] = true
	end
	table.sort(commandHandler.sortedPermissionNames)
	commandHandler.emitter:emit("onLoad")
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
	return utils.sendEmbed(channel, "Usage: ".."`"..guildSettings.prefix..command.name..(command.usage~="" and " "..command.usage or "").."`", "ff0000", "Angled brackets represent required arguments. Square brackets represent optional arguments. Do not include the brackets in the command. All values are case sensitive.")
end

commandHandler.getCommandSettings = function(guild, command, conn)
	local resultset = conn:exec("SELECT * FROM commands WHERE guild_id = '"..guild.id.."' AND command = '"..command.name.."';")
	return utils.formatRow(resultset)
end

commandHandler.getPermissions = function(guild, command, conn)
	local permissions = commandHandler.getCommandSettings(guild, command, conn).permissions
	local currentCommand = command
	while not permissions and currentCommand.isSubcommand do
		currentCommand = currentCommand.parentCommand
		permissions = commandHandler.getCommandSettings(guild, currentCommand, conn).permissions
	end
	return permissions
end

commandHandler.getPermissionsString = function(guild, command, conn)
	local permissions = commandHandler.getPermissions(guild, command, conn)
	return #permissions>0 and "`"..table.concat(permissions, "`, `").."`" or "None"
end

commandHandler.sendCommandHelp = function(channel, guildSettings, command, conn)
	local baseCommand = command.baseCommand
	local commandSettings = commandHandler.getCommandSettings(channel.guild, command, conn)
	if not commandSettings.is_enabled then
		channel:send{
			embed = {
				title = guildSettings.prefix..command.name,
				description = "`"..guildSettings.prefix..command.name.."` is disabled in this server.",
				color = discordia.Color.fromHex("ff0000").value
			}
		}
	else
		local subcommandsKeys = table.keys(command.subcommands)
		table.sort(subcommandsKeys)
		local permissionsString = commandHandler.getPermissionsString(channel.guild, command, conn)
		local subcommandsString = #subcommandsKeys>0 and "`"..table.concat(subcommandsKeys, "`, `").."`" or "None"

		channel:send{
			embed = {
				title = guildSettings.prefix..command.name,
				description = command.description:gsub("%&prefix%;", guildSettings.prefix),
				fields = {
					{name = "Category", value = baseCommand.category},
					{name = "Required permissions", value = permissionsString},
					{name = "Subcommands", value = subcommandsString},
					{name = "Usage", value = "`"..guildSettings.prefix..command.name..(command.usage~="" and " "..command.usage or "").."`"}
				},
				color = discordia.Color.fromHex("00ff00").value,
				footer = {
					text = "Angled brackets represent required arguments. Square brackets represent optional arguments. Do not include the brackets in the command. All values are case sensitive."
				}
			}
		}
	end
end

commandHandler.sendPermissionError = function(channel, missingPermissions)
	return utils.sendEmbed(channel, "You may not use this command because you are missing the following required permission"..utils.s(#missingPermissions)..": `"..table.concat(missingPermissions, "`, `").."`", "ff0000")
end

local function runStmtOnSubcommands(stmt, guild, command)
	for _, subcommand in pairs(command.subcommands) do
		stmt:reset():bind(guild.id, subcommand.name):step()
		runStmtOnSubcommands(stmt, guild, subcommand)
	end
end

commandHandler.enableCommand = function(guild, command, conn)
	if command.isSubcommand then
		if not commandHandler.getCommandSettings(guild, command.parentCommand, conn).is_enabled then
			return false, "This command's parent command is disabled, so this command cannot be enabled."
		end
	end

	if command.onEnable then
		local success, output = command:onEnable(guildSettings, conn)
		if not success then
			return false, output
		end
	end

	local stmt = conn:prepare("UPDATE commands SET is_enabled = 1 WHERE guild_id = ? AND command = ?;")
	stmt:reset():bind(guild.id, command.name):step()
	runStmtOnSubcommands(stmt, guild, command)
	stmt:close()
	return true, (output or "The command "..(#command.subcommands>0 and "and its subcommands were" or "was").." successfully enabled.")
end

commandHandler.disableCommand = function(guild, command, conn)
	if command.onDisable then
		local success, output = command:onDisable(guildSettings, conn)
		if not success then
			return false, output
		end
	end

	local stmt = conn:prepare("UPDATE commands SET is_enabled = 0 WHERE guild_id = ? AND command = ?;")
	stmt:reset():bind(guild.id, command.name):step()
	runStmtOnSubcommands(stmt, guild, command)
	stmt:close()
	return true, (output or "The command "..(#command.subcommands>0 and "and its subcommands were" or "was").." successfully disabled.")
end

commandHandler.toggleCommand = function(guild, command, conn)
	local commandSettings = commandHandler.getCommandSettings(guild, command, conn)

	if commandSettings.is_enabled then
		return commandHandler.disableCommand(guild, command, conn)
	else
		return commandHandler.enableCommand(guild, command, conn)
	end
end

commandHandler.setCommandPermissions = function(guild, command, conn, newPermissions)
	local stmt = conn:prepare("UPDATE commands SET permissions = ? WHERE guild_id = ? AND command = ?;")
	stmt:reset():bind(json.encode(newPermissions), guild.id, command.name):step()
	stmt:close()
end

commandHandler.getMissingPermissions = function(member, permissions)
	local missingPermissions = {}
	for _,permission in pairs(permissions) do
		if permission:match("^bot%.") then
			if not commandHandler.customPermissions[permission:match("^bot%.(.+)")](member) then
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
	if message.content~=content and command then
		local argString, args
		if command.subcommands~={} then
			command, argString, args = commandHandler.subcommandFromString(command, content)
		else
			argString = content:gsub("^"..commandString.."%s*","")
			args = argString:split("%s")
		end
		local commandSettings = commandHandler.getCommandSettings(message.guild, command, conn)
		if commandSettings.is_enabled then
			local permissions = commandHandler.getPermissions(message.guild, command, conn)
			local missingPermissions = commandHandler.getMissingPermissions(message.member, permissions)
			if #missingPermissions==0 then
				command:run(message, argString, args, guildSettings, conn)
			else
				commandHandler.sendPermissionError(message.channel, missingPermissions)
			end
			if guildSettings.delete_command_messages then message:delete() end
		end
	end
end

return commandHandler