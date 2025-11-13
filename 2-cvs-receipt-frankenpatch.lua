--[[ 2-cvs-receipt-frankenpatch-v2.0.9.2 ]]
-- added switch for book complete box 
-- landscape view widget width fix

local Blitbuffer = require("ffi/blitbuffer")
local bookCompleted = false
local CenterContainer = require("ui/widget/container/centercontainer")
local datetime = require("datetime")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local ProgressWidget = require("ui/widget/progresswidget")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
local Screen = Device.screen	
local Size = require("ui/size")
local SQ3 = require("lua-ljsqlite3/init")
local T = require("ffi/util").template
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local _ = require("gettext")

local showBookCompleteBox = true --set this to false to disable 'book complete' box

local quicklookbox = InputContainer:extend{  
    modal = true,  
    name = "quick_look_box",  
}  

function quicklookbox:init()

	-- book info
	local book_title = ""
    local book_author = ""
    if self.ui.doc_props then
        book_title = self.ui.doc_props.display_title or ""
        book_author = self.ui.doc_props.authors or ""
        if book_author:find("\n") then -- Show first author if multiple authors
            book_author =  T(_("%1 et al."), util.splitToArray(book_author, "\n")[1] .. ",")
        end
    end
	
    -- page count and book percentage
	
    local book_page = self.state.page or 1 -- Current page
    local book_total = self.ui.doc_settings.data.doc_pages or 1
    local book_left  = book_total - book_page
    local book_percentage = (book_page / book_total) * 100 -- Format like %.1f in header_string below
	
	-- since book_page, book_total and book_left will be later reassigned to corr. stable pages,
	local book_pageturn = book_page
	local book_pageturn_total = book_total
	local book_pageturn_left = book_left

    -- chapter Info
	
    local chapter_title = ""
    local chapter_total = 0
    local chapter_left = 0
    local chapter_done = 0
    if self.ui.toc then
        chapter_title = self.ui.toc:getTocTitleByPage(book_page) or "" -- Chapter name
        chapter_total = self.ui.toc:getChapterPageCount(book_page) or book_total
        chapter_left = self.ui.toc:getChapterPagesLeft(book_page) or self.ui.document:getTotalPagesLeft(book_page)
        chapter_page = self.ui.toc:getChapterPagesDone(book_page) or 0
    end
    chapter_page = chapter_page + 1 -- This +1 is to include the page you're looking at
	
	-- stable page numbers
	
	if self.ui.pagemap and self.ui.pagemap:wantsPageLabels() then
		book_page = self.ui.pagemap:getCurrentPageLabel(true) 	-- these two are strings. let's keep them that way to accommodate
		book_total = self.ui.pagemap:getLastPageLabel(true) 	-- roman number pages or whatever other perversions the publisher might subscribe to.
	end
	
	-- clock:
	
    local current_time = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock")) or ""
	
    -- battery:
	
    local battery = ""
    if Device:hasBattery() then
        local power_dev = Device:getPowerDevice()
        local batt_lvl = power_dev:getCapacity() or 0
        local is_charging = power_dev:isCharging() or false
        local batt_prefix = power_dev:getBatterySymbol(power_dev:isCharged(), is_charging, batt_lvl) or ""
        battery = batt_prefix .. batt_lvl .. "%"
    end
	
	-- time left in book and chapter
	
	local ReaderStatistics = self.ui.statistics
	
	local function secs_to_timestring(secs)
		local timestring = ""
		
		if not secs then
			timestring = false
			return timestring
		end
		
		local h = math.floor(secs/3600)
		local m = math.floor((secs % 3600)/60)
		local htext = "hrs"
		local mtext = "mins"		

		if h == 1 then htext = "hr" end
		if m == 1 then mtext = "min" end
		
		if h == 0 and m > 0 then
			timestring = string.format("%i %s", m, mtext)
		elseif h > 0 and m == 0 then
			timestring = string.format("%i %s", h, htext)
		elseif h > 0 and m > 0 then
			timestring = string.format("%i %s %i %s", h, htext, m, mtext)
		elseif h == 0 and m == 0 then
			timestring = "less than a minute"
		else
			timestring = "calculating time"
		end
		return timestring			
	end
	
	local function time_left_in_secs(pages)
	
		local avg_time_per_page = false  
			if ReaderStatistics then  
				avg_time_per_page = ReaderStatistics.avg_time  
			end  

		local total_secs			 
		if not avg_time_per_page then
		  total_secs = false
		  return total_secs
		end

		total_secs = avg_time_per_page * pages			 
		return total_secs
	end
		
	local book_time_left = secs_to_timestring(time_left_in_secs(book_left)) 		-- 'if book_time_left' is used everywhere to check if 
	local chapter_time_left = secs_to_timestring(time_left_in_secs(chapter_left))	-- reading stats is enabled in koreader settings.
	
	-- time read today, pages read today
	
	local time_read_today, pages_read_today = ReaderStatistics:getTodayBookStats() 	-- stats for today across all books
	local time_read_today_string = secs_to_timestring(time_read_today)	
	
	local pages_text = "pgs"
	if pages_read_today == 1 then 
		pages_text = "pg"
	end
	
	
	--==================== main widget layout ====================--			
		
	local screen_width = Screen:getWidth()
	local screen_height = Screen:getHeight()
	local w_width = math.floor(screen_width / 2)	
	if screen_width > screen_height then
		w_width = math.floor(w_width*screen_height/screen_width)
	end	
	
	local w_fontcolor = Blitbuffer.COLOR_BLACK
	local w_fontcolor_lighter = Blitbuffer.COLOR_GRAY_1
	local w_fontcolor_lightest = Blitbuffer.COLOR_GRAY_9
	local w_fontface = "NotoSans-Regular.ttf"
	local w_fontface_italic = "NotoSans-Italic.ttf"
	local w_fontface_bold = "NotoSans-Bold.ttf"
	local w_fontface_bolditalic = "NotoSans-BoldItalic.ttf"
	local w_fontsize_big = 25
	local w_fontsize_mid = 18
	local w_fontsize_small = 15
	local w_fontsize_tiny = 13
	local w_padding = Screen:scaleBySize(20) 			-- padding b/w framecontainer and widgets
	local w_padding_internal = Screen:scaleBySize(12) 	-- vertical padding between widgets
	
	local function vertical_spacing(h) 
		if h == nil then h =1 end
		local s = VerticalSpan:new{ width = math.floor(w_padding_internal*h),}
		return s
	end
		
	local function boxtype(book_or_ch)
		
		local widget = TextWidget:new{
		  text = book_or_ch,
		  face = Font:getFace(w_fontface_bold, w_fontsize_big),
		  fgcolor = w_fontcolor,
		}
		return widget
	end
		
	function itemname(book_or_ch_name)
		
		local widget = TextBoxWidget:new{
		  face = Font:getFace(w_fontface, w_fontsize_mid),
		  text = string.lower(book_or_ch_name),
		  width = w_width,
		  fgcolor = w_fontcolor,
		}
		return widget
	end
	
	function progressmodule(pgturn, pgturn_total, st_pageno, st_pagetotal) -- last two args rep. stable pages.
		
		if st_pageno == nil then st_pageno = pgturn end
		if st_pagetotal == nil then st_pagetotal = pgturn_total end
		
		local progressbarwidth = w_width
		
		local prog_bar = ProgressWidget:new{
		  width = progressbarwidth,
		  height = Screen:scaleBySize(2) ,
		  percentage = pgturn/pgturn_total,
		  margin_v = 0,
		  margin_h = 0,
		  radius = 0,
		  bordersize = 0,
		  fillcolor = w_fontcolor,
		  bgcolor = Blitbuffer.COLOR_GRAY,
		}
		
		local page_x_of_y = TextWidget:new {
		  text = string.format("page %s of %s", tostring(st_pageno), tostring(st_pagetotal)),
		  face = Font:getFace(w_fontface, w_fontsize_small),
		  bold = false,
		  fgcolor = w_fontcolor_lighter,
		  align = "left"
		}
		
		local percentage_display = TextWidget:new {
		  text = string.format("%i%%", pgturn/pgturn_total*100 ),
		  face = Font:getFace(w_fontface, w_fontsize_small),
		  bold = false,
		  fgcolor = w_fontcolor_lighter,
		  align = "right"
		}	
		
		local p_module = VerticalGroup:new{
							  prog_bar,
							  HorizontalGroup:new{
								page_x_of_y, 
								HorizontalSpan:new{width = progressbarwidth - page_x_of_y:getSize().w - percentage_display:getSize().w},
								percentage_display,
							  }
						}
		return p_module
	end
	
	function time_left_display(timeleftstring, book_or_ch)	
	
		local tldfont = w_fontface_bolditalic
		if not book_time_left or time_read_today < 60 then 
			tldfont = w_fontface_italic
		end	
		
		displayText = string.format("%s left in %s", timeleftstring, book_or_ch)
		if not book_time_left then
			displayText = string.format("-- left in %s", book_or_ch)
		end		
		
		local widget= TextWidget:new {
		  text = displayText,
		  face = Font:getFace(tldfont, w_fontsize_small),
		  bold = false,
		  fgcolor = w_fontcolor_lighter,
		  padding = 0,
		  alignment = "center",
		}
					
		return widget
	end										
	
	local batt_pct_box = TextBoxWidget:new {
		text = battery,
		face = Font:getFace(w_fontface, w_fontsize_small),
		bold = false,
		fgcolor = w_fontcolor,
		padding = 0,
		width = w_width/2,
		alignment = "left",
	  }
	
	local glyph_clock = "⌚"	
	local time_box = TextBoxWidget:new {
		text = string.format("%s%s", glyph_clock, current_time),
		face = Font:getFace(w_fontface, w_fontsize_small),
		bold = false,
		fgcolor = w_fontcolor,
		padding = 0,
		width = w_width/2,
		alignment = "right",
	  }
	 
	local time_read_today_box = function()
	
		local widget = TextWidget:new{
			  face = Font:getFace(w_fontface_italic, w_fontsize_small),
			  text = string.format("%s %s · %s read today", pages_read_today, pages_text, time_read_today_string),
			  fgcolor = w_fontcolor_lighter,
			  alignment = "center",
			}				
		
		if not book_time_left or time_read_today < 60 then -- if time read < 1 min, hide time_read_today_box
			return false
		end	
				
		return widget
	end
															
															
	local bottom_bar = function()
			local widget = HorizontalGroup:new{
					batt_pct_box,
					--bottom_bar_data_module,
					time_box,
					}	  
			return widget
	end
  
	local bookboxtitle = string.format("%s - %s", book_title, book_author)	
	
	local tleftb = time_left_display(book_time_left, "book")
	local trtbox = time_read_today_box()
	local bbar = bottom_bar()
	
	local structure = {
					boxtype("chapter"),
					itemname(chapter_title),
					progressmodule(chapter_page, chapter_total),
					time_left_display(chapter_time_left, "chapter"),
					
					boxtype("book"),
					itemname(bookboxtitle),
					progressmodule(book_pageturn, book_pageturn_total, book_page, book_total),
					tleftb,						
					
					trtbox,
					bbar,
					}		
					
					
	local structure_fixed = VerticalGroup:new{} 	-- filters out hidden widgets, adds spacing after
	for index, widget in ipairs(structure) do		-- everything except 'time left in book' and bottom_bar
		if widget then
			structure_fixed[#structure_fixed + 1] = widget			
			if widget == bbar then 
				structure_fixed[#structure_fixed + 1] = nil
			elseif widget == tleftb and trtbox then 
				structure_fixed[#structure_fixed + 1] = nil
			elseif widget == tleftb and not trtbox then 
				structure_fixed[#structure_fixed + 1] = vertical_spacing(1.3)
			else
				structure_fixed[#structure_fixed + 1] = vertical_spacing()
			end
		end
	end

	--==================== 'book completed' widget ====================--		
	
	-- stats plugin returns book start date as a a poorly formatted string, 
	-- so we grab the book start timestamp directly from the sql instead.						
	
	-- book start date 

	local timestamp_now = os.time()
	local secsInOneDay = 3600*24
	local secs_since_midnight = function(timestamp)
		local tsm = timestamp % secsInOneDay
		return tsm
	end		
	local timestamp_midnight = timestamp_now - secs_since_midnight(timestamp_now) -- timestamp for 12am today
	
	local id_book = ReaderStatistics.id_curr_book
	
	local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
	local conn = SQ3.open(db_location)
	sql_stmt = [[
		SELECT min(start_time)			   
		FROM   page_stat
		WHERE  id_book = %d;
    ]]
		
	local bookStartTimestamp = 0
	if book_time_left then
		bookStartTimestamp = conn:rowexec(string.format(sql_stmt, id_book))
		conn:close()
	end	
	if not bookStartTimestamp then bookStartTimestamp = timestamp_now end 
	
	local timeOfDay_now = secs_since_midnight(timestamp_now)
	local timeOfDay_bookstart = secs_since_midnight(bookStartTimestamp)	
	
	local daysAgo = (timestamp_now - bookStartTimestamp) / secsInOneDay
	if timeOfDay_now < timeOfDay_bookstart and timeOfDay_bookstart < timestamp_midnight then
		daysAgo = daysAgo + 1
	end	
	local daysAgoString = "--"	
	if not book_time_left then
		daysAgoString = "--"
	elseif daysAgo == 0 then 
		daysAgoString = "today"
	elseif daysAgo == 1 then
		daysAgoString = "yesterday"																																	
	else 
		daysAgoString = string.format("%i days ago", daysAgo)
	end
	
	local bookStartDate = ""
	if book_time_left then bookStartDate = os.date("%d-%m-%Y", tonumber(bookStartTimestamp)) end
	
	-- book time read and highlight count
	
	local bookReadTime = 0 -- from first opened till now
	local bookReadPages = 0
	local highlightCount = 0	
	if book_time_left then 
		bookReadPages, bookReadTime = ReaderStatistics:getPageTimeTotalStats(ReaderStatistics.id_curr_book)
		highlightCount = ReaderStatistics:getCurrentStat()[15][2]
	end
	
	local bookReadTime_string = ""	
	if book_time_left then
		bookReadTime_string = string.format("read for %s", secs_to_timestring(bookReadTime))
	end
	
	local highlight_text = "highlights"
	if highlightCount == 1 then 
		highlight_text = "highlight"
	end	
	local highlightCount_string = ""
	if book_time_left then
		highlightCount_string = string.format("%i %s", highlightCount, highlight_text)
	end

	local bookCompleteStats = "--"
	if book_time_left then
		bookCompleteStats = string.format("%s\nstarted %s (%s)\n%s", bookReadTime_string, daysAgoString, bookStartDate, highlightCount_string )
	end	
	
	--===================== widget layout =====================--	
	
	local bcWidgetWidth = math.floor(screen_width/2.5)
	if screen_width > screen_height then
		bcWidgetWidth = math.floor(bcWidgetWidth*screen_height/screen_width)
	end
	
	local bookCompleteBox = VerticalGroup:new{
							TextWidget:new {
									  text = "book complete!",
									  face = Font:getFace(w_fontface_bolditalic, w_fontsize_mid),
									  bold = false,
									  fgcolor = w_fontcolor,
									  padding = 0,
									  alignment = "center",
									},
							vertical_spacing(0.5),
							TextBoxWidget:new{
									  face = Font:getFace(w_fontface_italic, w_fontsize_small),
									  text = bookCompleteStats,
									  fgcolor = w_fontcolor,
									  alignment = "center",
									  width = bcWidgetWidth,
									}
							}										
	
	if bookCompleted then structure_fixed = bookCompleteBox end		

	local frameRadius = Screen:scaleBySize(22) 
	local framePadding = w_padding	
	if bookCompleted then frameRadius = Screen:scaleBySize(10)  framePadding = w_padding/2 end
	
	local final_frame = FrameContainer:new{
						radius = frameRadius,
						bordersize = Screen:scaleBySize(2) ,
						padding = framePadding,
						padding_top = math.floor(w_padding/2.1),
						padding_bottom = math.floor(w_padding/1.1),
						background = Blitbuffer.COLOR_WHITE, 
						structure_fixed,
						}
						
	
	self[1] = CenterContainer:new{
		  dimen = Screen:getSize(), 
		  VerticalGroup:new{
		  final_frame,
		  }
	}
	
	-- taps and keypresses
	
	if Device:hasKeys() then        
        self.key_events.AnyKeyPressed = { { Device.input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = function() return self.dimen end,
            }
        }
		self.ges_events.Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.dimen end,
            }
        }
        self.ges_events.MultiSwipe = {
            GestureRange:new{
                ges = "multiswipe",
                range = function() return self.dimen end,
            }
        }
    end
	
end

function quicklookbox:onTap()
    UIManager:close(self)
end

function quicklookbox:onSwipe(arg, ges_ev)
    if ges_ev.direction == "south" then
        -- Allow easier closing with swipe up/down
        self:onClose()
    elseif ges_ev.direction == "east" or ges_ev.direction == "west" or ges_ev.direction == "north" then
        self:onClose()-- -- no use for now
        -- do end -- luacheck: ignore 541
    else -- diagonal swipe
		self:onClose()

    end
end

function quicklookbox:onClose()
    UIManager:close(self)
    return true
end

quicklookbox.onAnyKeyPressed = quicklookbox.onClose

quicklookbox.onMultiSwipe = quicklookbox.onClose

-- add to dispatcher

Dispatcher:registerAction("quicklookbox_action", {
							category="none", 
							event="QuickLook", 
							title=_("cvs receipt"), 
							reader=true,})

function ReaderUI:onQuickLook()
	
	if self.statistics then  
        self.statistics:insertDB()  
    end 
	
	bookCompleted = false
	
    local widget = quicklookbox:new{
        ui = self,
        document = self.document,
        state = self.view and self.view.state,
    }
	
	UIManager:show(widget)
end

function ReaderUI:onEndOfBook()
	
	if self.statistics then  
        self.statistics:insertDB()  
    end 
	
	bookCompleted = true
		
    local widget = quicklookbox:new{
        ui = self,
        document = self.document,
        state = self.view and self.view.state,
    }	
	
	if showBookCompleteBox then UIManager:show(widget) end
end





