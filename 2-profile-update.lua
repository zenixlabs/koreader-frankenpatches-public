--[[ 2-profile-update.lua ]]
--adds 'update' option to profile submenu

--[ v1.0.1 ]
--break if at least one profile submenu has 'update' option

local userpatch = require("userpatch")
local ffiUtil = require("ffi/util")
local util = require("util")
local _ = require("gettext")
local T = ffiUtil.template
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local function updateOptionExists(tbl)
	--checks if "Update" option already exists in the menu table
	
	tbl = tbl and tbl or {}
	
	for __, item in ipairs(tbl) do
		if item.text == _("Update") then
			return true
		end
	end
	return false
end

local function insertUpdateOption(plugin)
	
	local Profiles = plugin
	local og_get_table = Profiles.getSubMenuItems
	
	function Profiles:getSubMenuItems()		
		local sub_menu_items = og_get_table(self)
		
		for __, item in ipairs(sub_menu_items) do
			local tbl = item.sub_item_table
			if tbl then
				if updateOptionExists(tbl) then
					break --if one profile submenu has it, all of them have it.
				else
					local update_menu_item = {
												text = _("Update"),
												enabled = self.document ~= nil,
												keep_menu_open = true,
												callback = function(touchmenu_instance)
													local curr_profile_name = item.text_func():gsub("\u{F0CA} ", ""):gsub("\u{F051} ", ""):gsub("\u{F144} ", "")
													UIManager:show(ConfirmBox:new{
														text = T(_("Are you sure you want to overwrite profile '%1' with current settings?"), curr_profile_name),
														ok_text = _("Update"),
														ok_callback = function()								
																self.data[curr_profile_name] = self:getProfileFromCurrentBookSettings(curr_profile_name)
																self.updated = true
																touchmenu_instance.item_table = self:getSubMenuItems()
																touchmenu_instance:updateItems()
																table.remove(touchmenu_instance.item_table_stack)
																UIManager:show(InfoMessage:new{
																					text = T(_("Profile '%1' was updated with current settings."), curr_profile_name),
																					timeout = 2,
																})
														end,
													})
												end,
					}
					table.insert(tbl, #tbl - 1, update_menu_item)
				end
			end
		end
		return sub_menu_items
	end
end
userpatch.registerPatchPluginFunc("profiles", insertUpdateOption)
