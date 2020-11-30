local rm = require("discordia-reaction-menu")
local utils = require("miscUtils")
local groupUtils = require("groupUtils")
local discordia = require("discordia")
local enums = discordia.enums

local yesWords = {["y"]=true, ["yes"]=true, ["t"]=true, ["true"]=true}
local noWords = {["n"]=true, ["no"]=true, ["f"]=true, ["false"]=true}
local converters = {
	boolean = function(self, message)
		local content = message.content:lower()
		return (yesWords[content] and 1) or (noWords[content] and 0) or false
	end,
	category = function(self, message)
		local category = (message.guild:getChannel(message.content)
			or message.guild.categories:find(function(c)
				return c.name:lower()==message.content:lower()
		 	end)
		 )
		return category and category.type==enums.channelType.category and category.id
	end,
	channel = function(self, message)
		local channel = (message.mentionedChannels.first
			or message.guild:getChannel(message.content)
			or message.guild.textChannels:find(function(c)
				return c.name==message.content:lower()
			end)
		)
		return channel and channel.type==enums.channelType.text and channel.id
	end,
	duration = function(self, message)
		local seconds = utils.secondsFromString(message.content)
		return seconds>0 and seconds
	end,
}

local settings = {
	{
		name = "Group Category",
		validValues = "id, name",
		column = "group_category_id",
		getValue = function(self, menu, data)
			local id = data.guildSettings[self.column]
			return id and menu.message.guild:getChannel(id).name or "not set"
		end,
		converter = converters.category
	},
	{
		name = "Group Channel",
		validValues = "mention, id, name",
		column = "group_channel_id",
		note = "Active group messages will continue to work, but will **not** be moved to the new channel",
		getValue = function(self, menu, data)
			local id = data.guildSettings[self.column]
			return id and menu.message.guild:getChannel(id).mentionString or "not set" 
		end,
		converter = converters.channel
	},
	{
		name = "Can Add/Remove Users to Locked Groups",
		validValues = "true, false",
		column = "can_add_remove_to_locked",
		isBool = true,
		getValue = function(self, menu, data)
			return data.guildSettings[self.column] and "true" or "false"
		end,
		converter = converters.boolean
	},
	{
		name = "Can Leave Locked Groups",
		validValues = "true, false",
		column = "can_leave_locked",
		isBool = true,
		getValue = function(self, menu, data)
			return data.guildSettings[self.column] and "true" or "false"
		end,
		converter = converters.boolean,
		onSet = function(self, menu, data, newValue)
			coroutine.wrap(function() -- update the text in all locked group embeds when this setting is changed
				local groups, nrow = data.conn:exec("SELECT message_id, group_num, name FROM groups WHERE guild_id = '"..menu.message.guild.id.."' AND is_locked = 1;")
				if not groups then return end
				local channel = menu.message.guild:getChannel(data.guildSettings.group_channel_id)
				for row = 1, nrow do
					local groupMessage = channel:getMessage(groups.message_id[row])
					groupUtils.updateLockedFields(groupMessage, groups.group_num[row], groups.name[row], true, data.guildSettings)
				end
			end)()
		end
	},
	{
		name = "Delete Command Messages",
		validValues = "true, false",
		column = "delete_command_messages",
		isBool = true,
		getValue = function(self, menu, data)
			return data.guildSettings[self.column] and "true" or "false"
		end,
		converter = converters.boolean
	},
	{
		name = "Delete Group Message on Group Delete",
		validValues = "true, false",
		column = "delete_group_messages",
		note = "This will not be done retroactively, i.e. groups deleted before this setting was changed will not have their messages deleted.",
		isBool = true,
		getValue = function(self, menu, data)
			return data.guildSettings[self.column] and "true" or "false"
		end,
		converter = converters.boolean
	},
	{
		name = "Give Back Group Roles on Server Rejoin",
		validValues = "true, false",
		column = "give_back_roles",
		note = "This will not be done retroactively, i.e. users who left before this setting was changed will not have their roles given back when they rejoin.",
		isBool = true,
		getValue = function(self, menu, data)
			return data.guildSettings[self.column] and "true" or "false"
		end,
		converter = converters.boolean
	},
	{
		name = "Mass Ping Cooldown Length",
		validValues = "length of time",
		column = "mass_ping_cooldown",
		note = "This setting is used for the `massping` command, which is disabled by default.\n-- Times should be input using the following format, representing minutes, hours, days, and weeks, respectively (order doesn't matter): `10m 20h 30d 40w`\n-- When the `massping` command is used, the cooldown is rounded to the nearest minute. For example, if the cooldown length is 10 minutes and the command is used at 1:00:20 am, the cooldown will expire at 1:10:00 am. If the cooldown length is 10 minutes and the command is used at 1:00:40, the cooldown will expire at 1:11:00 am.\n-- Changing the value of this setting will reset any ongoing mass ping cooldown in this server.",
		getValue = function(self, menu, data)
			return utils.secondsToTime(data.guildSettings[self.column])
		end,
		converter = converters.duration,
		onSet = function(self, menu, data, newValue)
			data.conn:exec("DELETE FROM ping_cooldowns WHERE guild_id="..menu.message.guild.id..";")
		end
	},
}

local choices = {}
for _,setting in ipairs(settings) do
	table.insert(choices, rm.Choice{
		name = setting.name,
		getValue = function(self, menu, data)
			return setting:getValue(menu, data)
		end,
		destination = rm.Page{
			title = "Settings: "..setting.name,
			getDescription = function(self, menu, data)
				return "Enter a new value for this setting.\n\n**Current value:** "..setting:getValue(menu, data).."\n**Valid values:** "..setting.validValues..(setting.note and "\n**Note:** "..setting.note or "")
			end,
			onPrompt = function(self, menu, data, message)
				local newValue = setting:converter(message)
				if not newValue then
					return rm.Page{
						title = "Settings: "..setting.name.." - Invalid value!",
						description = "That value is not valid for this setting.",
						choices = {rm.Choice{
							name = "Try again",
							destination = self
						}},
						inHistory = false,
						color = "ff0000"
					}
				elseif newValue==data.guildSettings[setting.column]
					or (setting.isBool and newValue==1 and data.guildSettings[setting.column]==true)
					or (setting.isBool and newValue==0 and data.guildSettings[setting.column]==false) then
						return rm.Page{
							title = "Settings: "..setting.name.." - Invalid value!",
							description = "This setting is already set to that value.",
							choices = {rm.Choice{
								name = "Try again",
								destination = self
							}},
							inHistory = false,
							color = "ff0000"
						}
				end
				local stmt = data.conn:prepare("UPDATE guild_settings SET "..setting.column.." = ? WHERE guild_id = ?;")
				stmt:reset():bind(newValue, menu.message.guild.id):step()
				stmt:close()
				if setting.isBool then
					if newValue==1 then
						data.guildSettings[setting.column] = true
					else
						data.guildSettings[setting.column] = false
					end
				else
					data.guildSettings[setting.column] = newValue
				end
				if setting.onSet then
					setting:onSet(menu, data, newValue)
				end
				return rm.Page{
					title = "Settings: "..setting.name.." - Updated!",
					description = "Value updated. New value: "..setting:getValue(menu, data),
					inHistory = false
				}
			end
		}
	})
end
local menu = rm.Menu{
	startPage = rm.paginateChoices(choices, "Settings", "Select a setting to edit its value."),
	maxChoices = 8,
	timeout = 300000
}

return {
	name = "settings",
	description = "Opens a reaction menu to view or edit bot settings in this server.",
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