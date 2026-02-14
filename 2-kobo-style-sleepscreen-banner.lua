--[[ 2-kobo-style-sleepscreen-banner.lua ]]
--redesigns the inbuilt 'banner' type sleep screen message to
--make it look like the kobo lockscreen tag.

--[ v2.0 ]
--release candidate

--CREDITS
--this version was written in collab with discord user @sandcastles.
--i've also borrowed some design cues from a similar patch written by reddit user u/juancoquet.

local B_SETT = {	--BANNER SETTINGS
					title_text = "%T", 	--configure title_text like you'd configure the inbuilt 
										--sleep screen message. for eg, "%T" shows book title,
										--"page %c of %t" shows 'page 1 of 400' etc.
					title_fontFace = "cfont",
					title_fontSize = 30,
					stats_fontFace = "cfont",
					stats_fontSize = 17,
					border_size = 1,
					border_color = 0,	-- 0 = white, 1 = black						
					background = 0,		-- 0 = white, 1 = black
					margin = 10,
					padding = 15,	
					max_height = 50,		-- percentage of screen height
					max_width_hl_off = 40,	-- width when highlight off, min: 20
					max_width_hl_on = 60,  	-- width when highlight on, min: 20
}
local HL_SETT = {	--HIGHLIGHT SETTINGS
					showRandomHighlight = true, 
					highlight_fontFace = "NotoSerif-Italic.ttf",
					highlight_fontSize = 16,
					justify = true,
					add_quotations = true,
					show_accent_line = true,					
					showHighlightFooter = true,
					hl_footer_fontFace = "NotoSerif-Regular.ttf",
					hl_footer_fontSize = 15,
					hl_footer_text = "saved on %DT at %HM", 	
										-- %DT = date, 
										-- %HM = time,
										-- %PG = page, 
										-- %C = chapter,
										-- %A = author, 
										-- %T = title, 
										-- \n = line break
												
					allowed_hl_styles = { 	-- only 'true' styles will be shown
									lighten = true,
									underscore = true,
									strikethrough = false,
									invert = false,
					}
}

local Bb = require("ffi/blitbuffer")
local BookInfo = require("apps/filemanager/filemanagerbookinfo")
local BookList = require("ui/widget/booklist")
local datetime = require("datetime")  
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Screen = Device.screen
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
local cached_random_highlight_index  = 1
local Sidecar

local function buildTextField(
								text, 
								font_face, 
								max_height, 
								max_wid, 
								ignoreLineBreaks, 
								isHighlight, 
								text_color
							)
	local wgt_grp = VerticalGroup:new{align = "left"}
	text = text:gsub("\\n", "\n")
	local segments = ignoreLineBreaks and {text} or util.splitToArray(text, "\n")
	for idx, item in ipairs(segments) do 
		local wgt = TextWidget:new{
						padding = 0,
						text = item,
						face = font_face,
						alignment = "left",
						fgcolor = text_color and text_color or 
									B_SETT.background == 1 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
						bgcolor = B_SETT.background == 0 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
		}
		if wgt:getSize().w > max_wid then 
			wgt:free()
			wgt = TextBoxWidget:new{
						text = item,
						face = font_face,
						width = max_wid,
						alignment = "left",
						height = max_height,
						height_adjust = true,
						height_overflow_show_ellipsis = true,
						justified = isHighlight and HL_SETT.justify,
						fgcolor = text_color and text_color or 
									B_SETT.background == 1 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
						bgcolor = B_SETT.background == 0 and Bb.COLOR_WHITE or 
									Bb.COLOR_BLACK,
			}			
		end		
		table.insert(wgt_grp, wgt)
	end
	return wgt_grp
end

local function addQuotesIfReq(text)
	if not text or text == "" then
		return text
	end
	local chars = util.splitToChars(text)  
	local first_char = chars[1]   
	local last_char = chars[#chars]
	local control = { {"'", "'"}, {"\"", "\""}, {"“", "”"}, 
						{"‘", "’"}, {"«", "»"}, {"„", "“"} }
	local quotesFound = false
	for _, quotes in ipairs(control) do 
		if first_char == quotes[1] and last_char == quotes[2] then 
			quotesFound = true
			break
		end
	end
	if not quotesFound then 
		return "“" .. text .. "”"
	end
	return text
end

local function parseFooterText(text, index)
	if not text or not index or text == "" then 
		return text, index 
	end
	
	local hl_time, hl_date, hl_chapter = "", "", ""
	local hl_pageno, bk_author, bk_title = 0, "", ""
	
	local hl_array = Sidecar and Sidecar:readSetting("annotations")
	hl_array = hl_array and hl_array[index] or {}
	hl_chapter = hl_array.chapter or "N/A"
	hl_pageno = Sidecar:isTrue("pagemap_use_page_labels") and hl_array.pageref or 
				hl_array.pageno or "N/A"
				
	local doc_props = Sidecar and Sidecar:readSetting("doc_props") or {}
	bk_author = doc_props.authors or "N/A"
	bk_title = doc_props.title or "N/A"
	
	--date and time
	local yr, mth, dy
	local date_and_time = hl_array.datetime and 
							util.splitToArray(hl_array.datetime, "%s+", false) or {}
	
	hl_date = date_and_time and date_and_time[1] or ""
	yr, mth, dy = hl_date:match("(%d+)-(%d+)-(%d+)")  
	local month_abbr = yr and mth and dy and 
						os.date("%b", os.time{year=yr, month=mth, day=dy}) or ""
	local short_month = datetime.shortMonthTranslation[month_abbr]  or ""
	hl_date = yr and mth and dy and short_month and 
				string.format("%s %s '%02d", dy, short_month, tonumber(yr) % 100) or "N/A"
	
	local timesplit = date_and_time and date_and_time[2] and 
					  util.splitToArray(date_and_time[2], ":") or {}
	hl_time = timesplit and timesplit[1] and timesplit[2] and 
			  timesplit[1]..":"..timesplit[2] or "N/A"
	
	local sub_table = {
		["%%HM"] = hl_time,
		["%%DT"] = hl_date,
		["%%PG"] = hl_pageno,
		["%%C"] = hl_chapter,
		["%%A"] = bk_author,
		["%%T"] = bk_title
	}	
	for pattern, replacement in pairs(sub_table) do
		if replacement then 
			text = string.gsub(text, pattern, replacement)
		end
	end
	return text	
end

local og_uiMan_show = UIManager.show

function UIManager:show(widget, ...)
	-- if widget isn't 'screensaver' or if wallpaper type
	-- isn't 'book cover' or 'custom image' or if sleep screen message type
	-- isn't 'banner', we do not intercept. 
	
	if widget.name ~= "ScreenSaver" then 
		return og_uiMan_show(self, widget, ...)
	end
	
	local screensaver_type = G_reader_settings:readSetting("screensaver_type")
	local message_container_enabled = G_reader_settings:isTrue("screensaver_show_message")
	local message_container_type = G_reader_settings:readSetting("screensaver_message_container")
	
	if not message_container_enabled or 
			message_container_type ~= "banner" then 
		return og_uiMan_show(self, widget, ...)
	end
	if screensaver_type ~= "cover" and 
			screensaver_type ~= "random_image" and 
			screensaver_type ~= "document_cover" then			
		return og_uiMan_show(self, widget, ...)
	end		
	--=================================
	
	local last_file = G_reader_settings:readSetting("lastfile")
	Sidecar = BookList.getDocSettings(last_file)
	self.ui = require("apps/reader/readerui").instance or 
				require("apps/filemanager/filemanager").instance
	Sidecar:flush()
	
	--dimen roundup	
	local dimen_ = {
			padding = B_SETT.padding and 
						Screen:scaleBySize(B_SETT.padding) or 
						Screen:scaleBySize(15),
			margin = B_SETT.margin and 
						Screen:scaleBySize(B_SETT.margin) or 
						Screen:scaleBySize(10),
			border_size = B_SETT.border_size and 
						Screen:scaleBySize(B_SETT.border_size) or 
						Screen:scaleBySize(1),
			line_width = Screen:scaleBySize(1),
			line_clearance = Size.padding.large,
			hl_wgt_clearance = Screen:scaleBySize(15),
			footer_clearance = Screen:scaleBySize(5),			
	}

	local overflow_h = (dimen_.padding + dimen_.margin + dimen_.border_size) * 2 + 
							dimen_.hl_wgt_clearance
	local overflow_w = (dimen_.padding + dimen_.margin + dimen_.border_size) * 2	
	local overflow_w_hl = HL_SETT.show_accent_line and 
							(overflow_w + dimen_.line_clearance + dimen_.line_width) or 
							overflow_w
	
	--font roundup
	local font_ = {
		title_font = Font:getFace(
						B_SETT.title_fontFace, 
						B_SETT.title_fontSize) or 
						Font:getFace("cfont", 30),
		stats_font = Font:getFace(
						B_SETT.stats_fontFace, 
						B_SETT.stats_fontSize) or 
						Font:getFace("cfont", 17),
		footer_font = Font:getFace(
						HL_SETT.hl_footer_fontFace, 
						HL_SETT.hl_footer_fontSize) or 
						Font:getFace("NotoSerif-Regular.ttf", 15),
		highlight_font = Font:getFace(
						HL_SETT.highlight_fontFace, 
						HL_SETT.highlight_fontSize) or 
						Font:getFace("NotoSerif-Italic.ttf", 16)					
	}
	
	local cus_pos_container, orig_sleep_widget, content_widget
	if widget and widget[1] and widget[1][1] and widget[1][1][2] and 
				widget[1][1][2].widget and widget[1][1][2].widget.text then 
	
		--intercept the custom position container and child.
		cus_pos_container = widget[1][1][2]
		orig_sleep_widget = widget[1][1][2].widget
		local orig_sleep_text = orig_sleep_widget.text
		orig_sleep_widget:free()
		
		local highlightCount, highlightEnabled, highlights_list
		
		if HL_SETT.showRandomHighlight then
			local all_annotations = Sidecar:readSetting("annotations") or {}
			highlights_list = {}

			local allowed = HL_SETT.allowed_hl_styles

			for _, item in ipairs(all_annotations) do
				if item.text
				   and item.drawer
				   and allowed[item.drawer] then
					local trimmed = util.trim(item.text)
					if trimmed ~= "" then
						table.insert(highlights_list, item)
					end
				end
			end

			highlightCount = #highlights_list
			highlightEnabled = highlightCount > 0
		end
		
		local hl_footer_enabled = highlightEnabled and 
									HL_SETT.showHighlightFooter and 
									HL_SETT.hl_footer_text and 
									util.trim(HL_SETT.hl_footer_text) ~= ""
		
		local max_wid
		if not highlightEnabled then
			max_wid = B_SETT.max_width_hl_off and
						B_SETT.max_width_hl_off >= 20 and 
						B_SETT.max_width_hl_off <= 100 and
						(B_SETT.max_width_hl_off/100 * screen_w) or 
						screen_w * 0.4
			max_wid = max_wid - overflow_w
		else
			max_wid = B_SETT.max_width_hl_on and
						B_SETT.max_width_hl_on >= 20 and 
						B_SETT.max_width_hl_on <= 100 and 
						(B_SETT.max_width_hl_on/100 * screen_w) or 
						screen_w * 0.6
			max_wid = max_wid - overflow_w_hl
		end			
		local max_height = B_SETT.max_height >= 20 and
							B_SETT.max_height <= 100 and
							(B_SETT.max_height/100 * screen_h) or 
							screen_h * 0.5
		max_height = max_height - overflow_h							
		
		--TITLE WIDGET
		local title_text
		
		if self.ui and self.ui.document and self.ui.toc and self.ui.bookinfo then
			title_text = self.ui and self.ui.bookinfo:expandString(B_SETT.title_text, last_file) or "N/A"
		else
			title_text = BookInfo:expandString(B_SETT.title_text, last_file) or "N/A"
		end
		
		local title_widget = buildTextField(
								title_text, 
								font_.title_font, 
								max_height, 
								max_wid, 
								true
		)
		local title_dimen = title_widget:getSize()					
		
		--STATS WIDGET
		local stats_widget = buildTextField(
								orig_sleep_text, 
								font_.stats_font, 
								max_height - title_dimen.h, 
								max_wid
		)
		local stats_dimen = stats_widget:getSize()
		
		--HIGHLIGHTS WIDGET
		local highlight_widget
		
		if highlightEnabled then 
			local random_highlight, random_highlight_index
			
			if highlightCount == 1 then
				random_highlight = highlights_list and highlights_list[1] and 
									highlights_list[1].text or ""
				random_highlight_index = 1
			else
				random_highlight_index = math.random(highlightCount)
				
				--get a diff random highlight from prev time.
				while random_highlight_index == cached_random_highlight_index do 
					random_highlight_index = math.random(highlightCount)
				end
				cached_random_highlight_index = random_highlight_index
				random_highlight = highlights_list[random_highlight_index] and 
									highlights_list[random_highlight_index].text or ""
			end
			
			random_highlight = util.trim(random_highlight)
			random_highlight = HL_SETT.add_quotations and addQuotesIfReq(random_highlight) or 
								random_highlight
			
			local hl_footer_widget
			local footer_color = B_SETT.background == 0 and 
									Bb.COLOR_GRAY_4 or 
									Bb.COLOR_GRAY_9
			
			if hl_footer_enabled then
				local hyphen_wid = buildTextField(
										"— ", 
										font_.footer_font,
										max_height, 
										max_wid, 
										true, 
										false, 
										footer_color
				)						
				hl_footer_widget = buildTextField(
										parseFooterText(HL_SETT.hl_footer_text , random_highlight_index), 
										font_.footer_font, 
										max_height - title_dimen.h - stats_dimen.h, 
										max_wid - hyphen_wid:getSize().w, 
										false, 
										false, 
										footer_color
				)						
				hl_footer_widget = HorizontalGroup:new{
										align = "top",
										hyphen_wid,
										hl_footer_widget
				}
				hl_footer_widget = VerticalGroup:new{
									VerticalSpan:new{width = dimen_.footer_clearance},
									hl_footer_widget,
				}
			end
			
			local hl_wgt_max_h = hl_footer_enabled and 
							(max_height - title_dimen.h - stats_dimen.h - hl_footer_widget:getSize().h) or 
							(max_height - title_dimen.h - stats_dimen.h)
			highlight_widget = buildTextField(
									random_highlight, 
									font_.highlight_font, 
									hl_wgt_max_h, 
									max_wid,
									true, 
									true
			)								
			local accent_height = highlight_widget:getSize().h
			
			-- if hl_footer_enabled and hl_footer_widget then
				-- highlight_widget = VerticalGroup:new{
						-- align = "left",
						-- highlight_widget,
						-- hl_footer_widget,
				-- }
			-- end
			
			if HL_SETT.show_accent_line then 			
				local highlight_accent = LineWidget:new{  
										background = footer_color,   
										dimen =  Geom:new{  
											w = dimen_.line_width,   
											h = accent_height, 
										},  
				}
				highlight_widget = HorizontalGroup:new{
					align = "top",
					highlight_accent,
					HorizontalSpan:new{width = dimen_.line_clearance},
					highlight_widget,
				}
			end
				
			if hl_footer_enabled and hl_footer_widget then
				highlight_widget = VerticalGroup:new{
						align = "left",
						highlight_widget,
						hl_footer_widget,
				}
			end
		end

		content_widget = VerticalGroup:new{
			align = "left",
			title_widget,
			stats_widget,			
		}
		
		if highlightEnabled and highlight_widget then
			table.insert(content_widget, VerticalSpan:new{width = dimen_.hl_wgt_clearance})
			table.insert(content_widget, highlight_widget)
		end
		
		content_widget = FrameContainer:new{                
			background = B_SETT.background == 0 and Bb.COLOR_WHITE or 
						 Bb.COLOR_BLACK,
			color = B_SETT.border_color == 0 and Bb.COLOR_WHITE or 
					Bb.COLOR_BLACK,
			margin = dimen_.margin,
			bordersize = dimen_.border_size,
			padding = dimen_.padding,
			content_widget,
		}		
		
		-- move custom position cont. to the left edge and replace child.
		cus_pos_container.horizontal_position = 0
		cus_pos_container.widget = content_widget
	end
	return og_uiMan_show(self, widget, ...)
end
