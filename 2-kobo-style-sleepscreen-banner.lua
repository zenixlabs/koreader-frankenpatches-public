--[[ 2-kobo-style-sleepscreen-banner.lua ]]
--redesigns the inbuilt 'banner' type sleep screen message to
--make it look like the kobo lockscreen tag.

--[ v1.0.5 ]
--change: handles line breaks better

local banner_settings = {	
						title_text = "%T", 	--configure title_text like you'd configure the inbuilt 
											--sleep screen message. for eg, "%T" shows book title,
											--"page %c of %t" shows 'page 1 of 400' etc.
											
						background = 0,		-- 0 = white, 1 = black
						margin = 10,
						title_fontFace = "cfont",
						title_fontSize = 30,
						stats_fontFace = "cfont",
						stats_fontSize = 17,
						border_size = 1,
						border_color = 1,	-- 0 = white, 1 = black
						padding = 15,
}

local Blitbuffer = require("ffi/blitbuffer")
local BookInfo = require("apps/filemanager/filemanagerbookinfo")
local BookList = require("ui/widget/booklist")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Screen = Device.screen
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")

local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()

local og_uiMan_show = UIManager.show

function UIManager:show(widget, ...)
	-- if widget isn't 'screensaver' or if wallpaper type
	-- isn't book cover or custom image or if sleep screen message type
	-- isn't 'banner', we don't intercept. 
	
	if widget.name ~= "ScreenSaver" then 
		return og_uiMan_show(self, widget, ...)
	end
	
	local screensaver_type = G_reader_settings:readSetting("screensaver_type")
	local message_container_enabled = G_reader_settings:isTrue("screensaver_show_message")
	local message_container_type = G_reader_settings:readSetting("screensaver_message_container")
	
	if not message_container_enabled or message_container_type ~= "banner" then 
		return og_uiMan_show(self, widget, ...)
	end
	if screensaver_type ~= "cover" and screensaver_type ~= "random_image" and screensaver_type ~= "document_cover" then
		return og_uiMan_show(self, widget, ...)
	end	
	
	--=================================
	
	local cus_pos_container, orig_sleep_widget, content_widget
	local stats_widgets = VerticalGroup:new{align = "left"}
	if widget and widget[1] and widget[1][1] and widget[1][1][2] and widget[1][1][2].widget and widget[1][1][2].widget.text then 
	
		--intercept the custom position container and child.
		cus_pos_container = widget[1][1][2]
		orig_sleep_widget = widget[1][1][2].widget
		local orig_sleep_text = orig_sleep_widget.text
		orig_sleep_widget:free()
		
		local last_file = G_reader_settings:readSetting("lastfile")
		self.ui = require("apps/reader/readerui").instance or require("apps/filemanager/filemanager").instance
		
		local title_text
		if self.ui and self.ui.document and self.ui.toc and self.ui.bookinfo then
			title_text = self.ui.bookinfo:expandString(banner_settings.title_text, last_file) or "N/A"
		else
			title_text = BookInfo:expandString(banner_settings.title_text, last_file) or "N/A"
		end
		
		local max_wid = screen_w * 0.4
		local title_widget = TextWidget:new{
			text = title_text,
			face = Font:getFace(banner_settings.title_fontFace, banner_settings.title_fontSize) or Font:getFace("cfont", 30),
			alignment = "left",
			fgcolor = banner_settings.background == 1 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
			bgcolor = banner_settings.background == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
		}			
		if title_widget:getSize().w > max_wid then 
			title_widget:free()
			title_widget = TextBoxWidget:new{
				text = title_text,
				face = Font:getFace(banner_settings.title_fontFace, banner_settings.title_fontSize) or Font:getFace("cfont", 30),
				width = max_wid,
				alignment = "left",
				fgcolor = banner_settings.background == 1 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
				bgcolor = banner_settings.background == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
			}			
		end
		
		-- we want to respect line breaks. hence:
		local stats_segments = util.splitToArray(orig_sleep_text, "\n")
		for idx, item in pairs(stats_segments) do
			local wgt = TextWidget:new{
				padding = 0,
				text = item,
				face = Font:getFace(banner_settings.stats_fontFace, banner_settings.stats_fontSize) or Font:getFace("cfont", 17),
				alignment = "left",
				fgcolor = banner_settings.background == 1 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
				bgcolor = banner_settings.background == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
			}
			if wgt:getSize().w > max_wid then 
				wgt:free()
				wgt = TextBoxWidget:new{
					--padding = Size.padding.small,
					text = item,
					face = Font:getFace(banner_settings.stats_fontFace, banner_settings.stats_fontSize) or Font:getFace("cfont", 17),
					width = max_wid,
					alignment = "left",
					fgcolor = banner_settings.background == 1 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
					bgcolor = banner_settings.background == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
				}			
			end
			table.insert(stats_widgets, wgt)
		end
		local title_dimen = title_widget:getSize()
		local stats_dimen = stats_widgets:getSize()
		local wid = math.max(title_dimen.w, stats_dimen.w)
		
		content_widget = VerticalGroup:new{
			align = "left",
			title_widget,
			stats_widgets,			
		}
		
		content_widget = FrameContainer:new{                
			background = banner_settings.background == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
			color = banner_settings.border_color == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
			margin = Screen:scaleBySize(banner_settings.margin) or Screen:scaleBySize(10),
			bordersize = Screen:scaleBySize(banner_settings.border_size) or Screen:scaleBySize(1),
			padding = Screen:scaleBySize(banner_settings.padding) or Screen:scaleBySize(15),
			content_widget,
		}		
		
		-- move custom position cont. to the left edge and replace child.
		cus_pos_container.horizontal_position = 0
		cus_pos_container.widget = content_widget

		return og_uiMan_show(self, widget, ...)
	end
end