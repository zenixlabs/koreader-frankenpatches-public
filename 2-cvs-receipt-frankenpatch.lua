--[[ 2-cvs-receipt-frankenpatch.lua ]]
--box with reading progress markers that can be summoned with a gesture

--[ v2.3.14 -public ]
--menu text

local Blitbuffer = require("ffi/blitbuffer")
local bookCompleted = false
local CenterContainer = require("ui/widget/container/centercontainer")
local datetime = require("datetime")
local DataStorage = require("datastorage")
local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Math = require("optmath")
local ProgressWidget = require("ui/widget/progresswidget")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local ReaderUI = require("apps/reader/readerui")
local ReaderView = require("apps/reader/modules/readerview")
local Screen = Device.screen
local Size = require("ui/size")
local SQ3 = require("lua-ljsqlite3/init")
local T = require("ffi/util").template
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local userpatch = require("userpatch")  
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local _ = require("gettext")
local N_ = _.ngettext
local WidgetContainer = require("ui/widget/container/widgetcontainer")

-- SWITCHES

local buttonProgressBarEnabled, showBookCompleteWindow, altFontEnabled, brtAuthorsEnabled = false, false, false, false
if G_reader_settings and G_reader_settings.isTrue then 
	buttonProgressBarEnabled = G_reader_settings:isTrue("cvs_rct_button_progbars")
	showBookCompleteWindow = G_reader_settings:isTrue("cvs_rct_book_complete_window")
	altFontEnabled = G_reader_settings:isTrue("cvs_rct_altFont")
	brtAuthorsEnabled = G_reader_settings:isTrue("cvs_rct_brtAuthors")
end

-- ADD TO MENU

local cvsMenu = {  
        text = _("CVS Receipt"),  
        sorting_hint = "tools",  
        sub_item_table = {  
            {  
                text = _("button style progress bars"),  
				help_text = _("button style progress bars inspired by old kindle firmwares. when unchecked, the receipt goes back to regular progress bars."),
                checked_func = function()  
                    return G_reader_settings:isTrue("cvs_rct_button_progbars")  
                end,  
                callback = function()  
                    G_reader_settings:flipNilOrFalse("cvs_rct_button_progbars")					
					buttonProgressBarEnabled = G_reader_settings:isTrue("cvs_rct_button_progbars")					
                end,  
            }, 
			{  
                text = _("'book complete' window"),
				help_text = _("a little window that pops up when you flip past the last page of a book. shows time read, starting date and highlight count for current book.\n\n(set Menu>gear icon>End of document action to 'Do nothing' for best results)."),
                checked_func = function()  
                    return G_reader_settings:isTrue("cvs_rct_book_complete_window")  
                end,  
                callback = function()  
					G_reader_settings:flipNilOrFalse("cvs_rct_book_complete_window")  
					showBookCompleteWindow = G_reader_settings:isTrue("cvs_rct_book_complete_window") 			
                end,  
            }, 
			{  
                text = _("show author(s) in 'books read today' window."),  
				help_text = _("uncheck this if for a cleaner, more minimal looking 'books read today' window."),
                checked_func = function()  
                    return G_reader_settings:isTrue("cvs_rct_brtAuthors")  
                end,  
                callback = function()  
                    G_reader_settings:flipNilOrFalse("cvs_rct_brtAuthors")  
					brtAuthorsEnabled = G_reader_settings:isTrue("cvs_rct_brtAuthors")
                end,  
            },			
			{  
                text = _("alt-font"),  
				help_text = _("monospace font (or any other font you've added via the lua file)."),
                checked_func = function()  
                    return G_reader_settings:isTrue("cvs_rct_altFont")  
                end,  
                callback = function()  
                    G_reader_settings:flipNilOrFalse("cvs_rct_altFont")  
					altFontEnabled = G_reader_settings:isTrue("cvs_rct_altFont") 			
                end,  
            },  
        },  
    }  

if not ReaderFooter._cvs_receipt_hooked then
	local orig_ReaderFooter_addToMainMenu_cvs = ReaderFooter.addToMainMenu
	ReaderFooter.addToMainMenu = function(self, menu_items)
		if orig_ReaderFooter_addToMainMenu_cvs then
			orig_ReaderFooter_addToMainMenu_cvs(self, menu_items)
		end
		menu_items.cvs_rct_menu = cvsMenu
	end 
	ReaderFooter._cvs_receipt_hooked = true
end

local quicklookwindow =
    InputContainer:extend {
    modal = true,
    name = "quick_look_window"
	}

function quicklookwindow:init()
	
    local ReaderStatistics = self.ui.statistics
    local statsEnabled = ReaderStatistics and ReaderStatistics.settings and ReaderStatistics.settings.is_enabled
    local ReaderToc = self.ui.toc	

    -- BOOK INFO

    local book_title = ""
    local book_author = ""
    if self.ui.doc_props then
        book_title = self.ui.doc_props.display_title or ""
        book_author = self.ui.doc_props.authors or ""
        if book_author:find("\n") then -- Show first author if multiple authors
            book_author = T(_("%1 et al."), util.splitToArray(book_author, "\n")[1] .. ",")
        end
    end

    -- PAGE COUNT AND BOOK PERCENTAGE

    local book_page = 0
    local book_total = 0
    local book_left = 0
    local book_percentage = 0
    if self.ui.document then
        book_page = self.state.page or 1 -- Current page
        book_total = self.ui.doc_settings.data.doc_pages or 1
        book_left = book_total - book_page
        book_percentage = (book_page / book_total) * 100 -- Format like %.1f in header_string below
    end

    -- CHAPTER INFO

    local chapter_title = ""
    local chapter_total = 0
    local chapter_left = 0
    local chapter_page = 0
    if ReaderToc then
        chapter_title = ReaderToc:getTocTitleByPage(book_page) or "" -- Chapter name
        chapter_page = ReaderToc:getChapterPagesDone(book_page) or 0
        chapter_page = chapter_page + 1 -- This +1 is to include the page you're looking at
        chapter_total = ReaderToc:getChapterPageCount(book_page) or book_total
        chapter_left = ReaderToc:getChapterPagesLeft(book_page) or book_left
    end

    -- BOOK PAGE TURNS (cuz everything gets reassigned with stable pages),

    local book_pageturn = book_page
    local book_pageturn_total = book_total
    local book_pageturn_left = book_left

    -- STABLE PAGES

    if self.ui.pagemap and self.ui.pagemap:wantsPageLabels() then
        book_page = self.ui.pagemap:getCurrentPageLabel(true) -- these two are strings.
        book_total = self.ui.pagemap:getLastPageLabel(true)
    end

    -- CLOCK

    local current_time = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock")) or ""

    -- BATTERY

    local battery = ""
    if Device:hasBattery() then
        local power_dev = Device:getPowerDevice()
        local batt_lvl = power_dev:getCapacity() or 0
        local is_charging = power_dev:isCharging() or false
        local batt_prefix = power_dev:getBatterySymbol(power_dev:isCharged(), is_charging, batt_lvl) or ""
        battery = batt_prefix .. batt_lvl .. "%"
    end

    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    local w_width = math.floor(screen_width / 2)
    if screen_width > screen_height then
        w_width = math.floor(w_width * screen_height / screen_width)
    end

    -- FONT AND PADDING

    local w_font = {
        face = {
            reg = "NotoSans-Regular.ttf",
            bold = "NotoSans-Bold.ttf",
            it = "NotoSans-Italic.ttf",
            boldit = "NotoSans-BoldItalic.ttf"
        },
        size = {big = 25, med = 18, small = 15, tiny = 13},
        color = {
            black = Blitbuffer.COLOR_BLACK,
            darkGray = Blitbuffer.COLOR_GRAY_1,
            lightGray = Blitbuffer.COLOR_GRAY_4
        }
    }
	local fontSizeCorrection = -1
	local monospaceFont = "DroidSansMono.ttf"
    if altFontEnabled then -- monospace
        w_font.face = {
            reg = monospaceFont,
            bold = monospaceFont,
            it = monospaceFont,
            boldit = monospaceFont
        }
        for key, value in pairs(w_font.size) do
            w_font.size[key] = value + fontSizeCorrection
        end
    end

    local w_padding = {
        internal = buttonProgressBarEnabled and Screen:scaleBySize(7) or Screen:scaleBySize(12),
        external = Screen:scaleBySize(20)
    } -- ext: between frame and widgets, int: verticalspace bw widgets (12)

    -- HELPER FUNCTIONS

    local function secsToTimestring(secs) -- seconds to 'x hrs y mins' format
        local timestring = ""

        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        local h_str = T(N_("1 hr", "%1 hrs", h), h)
        local m_str = T(N_("1 min", "%1 mins", m), m)

        if h == 0 and m < 1 then
            return "less than a minute"
        else
            if h >= 1 then timestring = timestring .. h_str .. " " end
            if m >= 1 then timestring = timestring .. m_str .. " " end
            timestring = timestring:sub(1, -2) -- remove the last space
        end

        return timestring
    end

    local function vertical_spacing(h) -- vertical space eq. to h*w_padding.internal
        if h == nil then
            h = 1
        end
        local s = VerticalSpan:new {width = math.floor(w_padding.internal * h)}
        return s
    end

    local function textt(txt, tfont, tsize, tclr, tpadding) -- creates TextWidget
        if not tclr then tclr = w_font.color.black end

        local w =
            TextWidget:new {
            text = txt,
            face = Font:getFace(tfont, tsize),
            fgcolor = tclr,
            bold = false,
			padding = tpadding or Screen:scaleBySize(2)
        }
        return w
    end

    local function getWidth(text, face, size) -- text width
        local t = textt(text, face, size)
        local width = t:getSize().w
        t:free()
        return width
    end

    local function textboxx(txt, tfont, tsize, tclr, twidth, tbold, alignmt, justif) -- creates TextBoxWidget
        if not tclr then tclr = w_font.color.black end
        if not tbold then tbold = false end
        if not justif then justif = false end
        if not alignmt then alignmt = "center" end
        local w =
            TextBoxWidget:new {
            text = txt,
            face = Font:getFace(tfont, tsize),
            fgcolor = tclr,
            bold = tbold,
            width = twidth,
            alignment = alignmt,
            justified = justif,            
            padding = 0
        }
        return w
    end

    -- CURRENT TIMESTAMP / MIDNIGHT TIMESTAMP

    local secsInOneDay = 3600 * 24
    local ts_now = os.time()
    local t = os.date("*t", ts_now)
    t.hour = 0
    t.min = 0
    t.sec = 0
    local ts_midnight_today = os.time(t)
	
	--============================================
    --'QUICK LOOK' WINDOW
	--============================================
	
    local function buildQuickLookWindow()
	
        -- we manually calculate chapter page, chapter total and chapter left in terms of pageturns.
		-- this is because we want progress % to update after every PAGETURN (because that feels more
		-- organic) as opposed to having it update every STABLEPAGE (one single stablepage might spread
		-- across multiple pageturns).
		
		local chapter_pgturn, chapter_pgturn_left, chapter_pgturn_total = 0, 0, 0
		local nextChapterTickPgturn, previousChapterTickPgturn = 0, 0
        if self.ui.pagemap and self.ui.pagemap:wantsPageLabels() and ReaderToc then -- if stable pages are ON and toc is available
            nextChapterTickPgturn = ReaderToc:getNextChapter(book_pageturn) or (book_pageturn_total + 1)
			previousChapterTickPgturn = ReaderToc:getPreviousChapter(book_pageturn) or 1
			if book_pageturn == 1 or ReaderToc:isChapterStart(book_pageturn) then previousChapterTickPgturn = book_pageturn end
			chapter_pgturn = book_pageturn - previousChapterTickPgturn +1
			chapter_pgturn_total = nextChapterTickPgturn - previousChapterTickPgturn
            chapter_pgturn_left = nextChapterTickPgturn - book_pageturn - 1
        else
            chapter_pgturn = chapter_page
			chapter_pgturn_total = chapter_total
			chapter_pgturn_left = chapter_left
        end	
	
        --=== QUICK LOOK WINDOW WIDGETS ===--

        local function boxtype(book_or_ch)
            local widget = textt(book_or_ch, w_font.face.bold, w_font.size.big)
            return widget
        end

        function itemname(book_or_ch_name)
            local t = string.lower(book_or_ch_name)
            local widget = textboxx(t, w_font.face.reg, w_font.size.med, w_font.color.black, w_width, false, "left")
            return widget
        end
		
		-- PROGRESS MODULE
		
        function progressmodule(pgturn, pgturn_total, st_pageno, st_pagetotal) 	-- last two args rep. stable pages.
            if st_pageno == nil then st_pageno = pgturn end						-- fallback to page turns if st. pgs. off	
            if st_pagetotal == nil then st_pagetotal = pgturn_total end

            local prog_pct = pgturn / pgturn_total
            local progressbarwidth = math.floor(w_width)
            local prog_bar

            local function normal_prog_bar(pct)
                local p =
                    ProgressWidget:new {
                    width = progressbarwidth,
                    height = Screen:scaleBySize(2),
                    percentage = pct,
                    margin_v = 0,
                    margin_h = 0,
                    radius = 0,
                    bordersize = 0,
                    fillcolor = w_font.color.black,
                    bgcolor = Blitbuffer.COLOR_GRAY
                }
                return p
            end

            local function buttonProgressBar(pct)
                local buttonFontFace = altFontEnabled and "DroidSansMono.ttf" or "NotoSans-Regular.ttf"
				
                -- helper: get buttonString
				
                local getButtonString = function(bChar, wid, bsize)
                    local charWidth = getWidth(bChar, buttonFontFace, bsize)
                    local maxCharNum = math.floor(wid / charWidth)
                    local bString = string.rep(bChar, maxCharNum)
                    return bString
                end

                local buttonFontSize_unread = 22
                local buttonFontSize_read = buttonFontSize_unread
                local buttonChar_unread = "·"
                local buttonChar_read = "•"
				
				local increment = 4 -- % increment for button progress bar. < 2 makes the bar fill up before touching 100
                local readWidth = (math.floor(pct * 100 / increment)) * increment / 100 * progressbarwidth
				
				-- read segment
				
				local readSegmentString = getButtonString(buttonChar_read, readWidth, buttonFontSize_read)
                local readButtonSegment = textt(readSegmentString, buttonFontFace, buttonFontSize_read, nil, 0) 
				
                local readSegmentHeight = readButtonSegment:getSize().h
                local paddingFix = altFontEnabled and Screen:scaleBySize(math.floor(0.05 * readSegmentHeight)) or 0
                local container_height = readSegmentHeight - paddingFix
                readButtonSegment.forced_height = container_height
				
				-- unread segment 
				
                local unreadWidth = progressbarwidth - readButtonSegment:getSize().w

                local unreadButtonSegment
                if altFontEnabled then
                    local unreadButtonString = getButtonString(buttonChar_unread, unreadWidth, buttonFontSize_unread)
                    unreadButtonSegment = textt(unreadButtonString, buttonFontFace, buttonFontSize_unread, nil, 0)                                   

                    unreadButtonSegment.forced_height = container_height
                else
                    local dotSeparation =
                        HorizontalSpan:new {width = ((getWidth(" ", buttonFontFace, buttonFontSize_unread)) / 3)}
                    local urButton = textt(buttonChar_unread, buttonFontFace, buttonFontSize_unread, nil, 0)

                    urButton.forced_height = container_height

                    local repeatingUnit =
                        HorizontalGroup:new {
                        dotSeparation,
                        urButton
                    }

                    local repeatingUnit_reqNum = math.floor(unreadWidth / repeatingUnit:getSize().w)
                    unreadButtonSegment = HorizontalGroup:new {}
                    for i = 1, repeatingUnit_reqNum do
                        table.insert(unreadButtonSegment, repeatingUnit)
                    end
                end

                local rem =
                    HorizontalSpan:new {
                    width = progressbarwidth - readButtonSegment:getSize().w - unreadButtonSegment:getSize().w
                }

                local container =
                    LeftContainer:new {
                    dimen = Geom:new {
                        w = progressbarwidth,
                        h = Screen:scaleBySize(26)
                    },
                    HorizontalGroup:new {
                        align = "center",
                        readButtonSegment,
                        unreadButtonSegment,
                        rem
                    }
                }

                return container
            end

            prog_bar = buttonProgressBarEnabled and buttonProgressBar(prog_pct) or normal_prog_bar(prog_pct)

            local pgXofY_txt = T(_("page %1 of %2"), st_pageno, st_pagetotal)
            local pageXofY = textt(pgXofY_txt, w_font.face.reg, w_font.size.small, w_font.color.darkGray)

            local percentage_display_txt = string.format("%i%%", prog_pct * 100)
            local percentage_display =
                textt(percentage_display_txt, w_font.face.reg, w_font.size.small, w_font.color.darkGray)

            local progressModule =
                VerticalGroup:new {
                prog_bar,
                HorizontalGroup:new {
                    pageXofY,
                    HorizontalSpan:new {width = w_width - pageXofY:getSize().w - percentage_display:getSize().w},
                    percentage_display
                }
            }
            return progressModule
        end

        -- TIME READ TODAY / PAGES READ TODAY

        local timeReadToday, pagesReadToday = 0, 0
        local timeReadToday_str, pagesReadToday_str = "", ""
        if self.ui.document and not bookCompleted then
            timeReadToday, pagesReadToday = ReaderStatistics:getTodayBookStats() -- stats for today across all books
            timeReadToday_str = string.format("%s read today", secsToTimestring(timeReadToday))
            pagesReadToday_str = T(N_("1 pg", "%1 pgs", pagesReadToday), pagesReadToday)
        end

        local time_read_today_box = function()
            local t = string.format("%s · %s", pagesReadToday_str, timeReadToday_str)
            local widget = textt(t, w_font.face.it, w_font.size.small, w_font.color.darkGray)

            if not statsEnabled or timeReadToday < 60 then -- if time read < 1 min, hide time_read_today_box
                return nil
            end
			local trt_wid = widget:getSize().w
			if trt_wid > w_width then w_width = trt_wid + Screen:scaleBySize(10) end
            return widget
        end

        -- TIME LEFT IN CHAPTER/BOOK

        local function timeLeft_secs(pages)
            local avgTimePerPgturn = 0
            if statsEnabled then
                avgTimePerPgturn = ReaderStatistics.avg_time
            end
            local total_secs = avgTimePerPgturn * pages
            return total_secs
        end

        local book_timeLeft = "calculating time"
        local chapter_timeLeft = "calculating time"
        if ReaderStatistics.avg_time and ReaderStatistics.avg_time > 0 then
            book_timeLeft = secsToTimestring(timeLeft_secs(book_pageturn_left + 1)) -- +1 to include current page when calc. time left
            chapter_timeLeft = secsToTimestring(timeLeft_secs(chapter_pgturn_left + 1))
        end

        function time_left_display(timeleftstring, book_or_ch)
            local tldfont = w_font.face.boldit
            if not statsEnabled or timeReadToday < 60 then
                tldfont = w_font.face.it
            end

            displayText = string.format("%s left in %s", timeleftstring, book_or_ch)
            if not statsEnabled then
                displayText = string.format("-- left in %s", book_or_ch)
            end

            local tldWidth = getWidth(displayText, tldfont, w_font.size.small, w_font)
            if tldWidth > w_width then
                w_width = tldWidth + Screen:scaleBySize(10)
            end -- monospace fonts take up more space

            local widget = textt(displayText, tldfont, w_font.size.small, w_font.color.darkGray)

            return widget
        end

        local batt_pct_box =
            textboxx(battery, w_font.face.reg, w_font.size.small, w_font.color.black, w_width / 2, false, "left")

        local glyph_clock = "⌚"
        local time_box_txt = string.format("%s%s", glyph_clock, current_time)
        local time_box =
            textboxx(time_box_txt, w_font.face.reg, w_font.size.small, w_font.color.black, w_width / 2, false, "right")

        local bottom_bar = function()
            local widget =
                HorizontalGroup:new {
                batt_pct_box,
                time_box
            }
            return widget
        end

        local bookboxtitle = string.format("%s - %s", book_title, book_author)

        local tleftc = time_left_display(chapter_timeLeft, "chapter")
        local tleftb = time_left_display(book_timeLeft, "book")
		local trtbox = time_read_today_box()
        local progModule_book = progressmodule(book_pageturn, book_pageturn_total, book_page, book_total)
        local progModule_ch = progressmodule(chapter_pgturn, chapter_pgturn_total, chapter_page, chapter_total)


        local quickLookWindow =
            VerticalGroup:new {
				boxtype("chapter"), 	--1
				vertical_spacing(), 	--2
				itemname(chapter_title),--3
				progModule_ch, 			--4
				vertical_spacing(), 	--5
				tleftc, 				--6
				vertical_spacing(), 	--7
				boxtype("book"), 		--8
				vertical_spacing(), 	--9
				itemname(bookboxtitle), --10
				progModule_book, 		--11
				vertical_spacing(), 	--12
				tleftb, 				--13
				vertical_spacing(1.2), 	--14
				bottom_bar() 			--15
			}

        if trtbox then
            table.insert(quickLookWindow, 14, trtbox)
        end
        if not buttonProgressBarEnabled then
            table.insert(quickLookWindow, 11, vertical_spacing())
            table.insert(quickLookWindow, 4, vertical_spacing())
        end

        return quickLookWindow
    end

	--============================================
    --'BOOK COMPLETE' WINDOW
	--============================================
	
    local function buildBookCompleteWindow()
        local id_book = 0
		if statsEnabled then id_book = ReaderStatistics.id_curr_book or 0 end

        -- book start date

        -- stats plugin returns book start date as a a poorly formatted string,
        -- so we grab the book start timestamp directly from the sql instead.

        local ts_bookStart = 0
        if bookCompleted and statsEnabled then
            local conn = SQ3.open(db_location)
            local sql_stmt_bookStartTimestamp =
												[[
													SELECT min(start_time)			   
													FROM   page_stat
													WHERE  id_book = %d;
												]]
            ts_bookStart = conn:rowexec(string.format(sql_stmt_bookStartTimestamp, id_book)) or ts_now
            conn:close()
        end

        -- seconds since 12am for book start time and current time

        local t_bookStart = os.date("*t", tonumber(ts_bookStart))
        t_bookStart.hour = 0
        t_bookStart.min = 0
        t_bookStart.sec = 0
        local ts_midnight_bookstartDay = os.time(t_bookStart)
        local secsSinceMidnight_now = ts_now - ts_midnight_today
        local secsSinceMidnight_bookstart = ts_bookStart - ts_midnight_bookstartDay

        local daysAgo = (ts_now - ts_bookStart) / secsInOneDay
        if secsSinceMidnight_now < secsSinceMidnight_bookstart then
            daysAgo = daysAgo + 1
        end
        local daysAgoTxt = ""
        if not statsEnabled then
            daysAgoTxt = "--"
        elseif daysAgo == 0 then
            daysAgoTxt = "started today"
        elseif daysAgo == 1 then
            daysAgoTxt = "started yesterday"
        else
            daysAgoTxt = string.format("started %i days ago", daysAgo)
        end

        local bookStartDate = ""
        if statsEnabled then
            bookStartDate = os.date("%d-%m-%Y", tonumber(ts_bookStart))
        end

        local startedOn_str = string.format("%s (%s)", daysAgoTxt, bookStartDate) -- "started x days ago (dd--mm--yyyy)"

        -- BOOK READ TIME / HIGHLIGHT COUNT

        local bookReadTime, bookPagesRead, highlightCount = 0, 0, 0 -- bookreadtime is from FIRST OPEN till NOW
        if statsEnabled and bookCompleted then
            local pages_placeholder, time_placeholder = ReaderStatistics:getPageTimeTotalStats(ReaderStatistics.id_curr_book)
			bookReadTime = time_placeholder or 0
			bookPagesRead = pages_placeholder or 0
			local ok, stats = pcall(ReaderStatistics.getCurrentStat, ReaderStatistics) 	-- using pcall to defend against some
			if ok and stats and stats[15] then  										-- unexpected crashes when launching bc window.
				highlightCount = tonumber(stats[15][2]) or 0  
			end           		
        end

        local bookReadTime_string = ""
        local bookCompleteStats = "--"
        local highlightCount_str = ""
        if statsEnabled then
            highlightCount_str = T(N_("1 highlight", "%1 highlights", highlightCount), highlightCount)
            bookReadTime_string = string.format("read for %s", secsToTimestring(bookReadTime))
            bookCompleteStats = string.format("%s\n%s\n%s", bookReadTime_string, startedOn_str, highlightCount_str)
        end

        -- WINDOW WIDTH

        local bcWidgetWidth = 0
        if not statsEnabled then
            bcWidgetWidth = getWidth("book complete!", w_font.face.boldit, w_font.size.med)
        else
			local wid1 = getWidth(startedOn_str, w_font.face.it, w_font.size.small)
			local wid2 = getWidth(bookReadTime_string, w_font.face.it, w_font.size.small)
			bcWidgetWidth = math.max(wid1, wid2)
		end

        local bookCompleteWindow = {}
        if bookCompleted then
            bookCompleteWindow =
                VerticalGroup:new {
                textboxx("book complete!", w_font.face.boldit, w_font.size.med, w_font.color.black, bcWidgetWidth),
                vertical_spacing(0.5),
                textboxx(bookCompleteStats, w_font.face.it, w_font.size.small, w_font.color.black, bcWidgetWidth)
            }
        end

        return bookCompleteWindow
    end

	--============================================
    --'BOOKS READ TODAY' WINDOW
	--============================================
	
    local function buildBooksReadTodayWindow()
        local booksReadToday = {}
        if not self.ui.document and statsEnabled then
            local conn = SQ3.open(db_location)
            local sql_stmt_booksReadToday =
											[[ 
												SELECT  book_tbl.title AS title,
														count(distinct page_stat_tbl.page),
														sum(page_stat_tbl.duration),
														book_tbl.id
												FROM    page_stat AS page_stat_tbl, book AS book_tbl
												WHERE   page_stat_tbl.id_book=book_tbl.id AND page_stat_tbl.start_time BETWEEN %d AND %d
												GROUP   BY book_tbl.id
												ORDER   BY book_tbl.last_open DESC;
											]]
            booksReadToday = conn:exec(string.format(sql_stmt_booksReadToday, ts_midnight_today + 1, ts_now))
            conn:close()
        end

        if statsEnabled and booksReadToday then
            for i = 1, #booksReadToday[1] do
                local p = tonumber(booksReadToday[2][i]) -- pages read today
                local p_str = T(N_("1 pg", "%1 pgs", p), p)
                local d = secsToTimestring(tonumber(booksReadToday[3][i])) -- time read
				if brtAuthorsEnabled then -- if authors enabled, then replaces "title" in [1][i] with "title - author(s)"
					local bookId = booksReadToday[4][i] -- grab book id
					local auth = ""
					local auth_str = ""
					if ReaderStatistics:getBookStat(bookId) then 
						auth = ReaderStatistics:getBookStat(bookId)[2][2] or ""
						if auth:find("\n") then
							auth = string.gsub(auth, "[\n]", ", ")
						end
						if auth ~= "N/A" then auth_str = string.format( " - %s", string.lower(auth)) end
						booksReadToday[1][i] = booksReadToday[1][i] .. auth_str -- append author(s) to book title
					end
				end
                booksReadToday[4][i] = string.format("%s · %s", p_str, d) -- replace book id in [4][i] with book stats string
			end
        end

        -- WINDOW WIDTH
		local brtWindowTitle = textt("books read today", w_font.face.boldit, w_font.size.med, w_font.color.black, 0)
        local brtWindowWidth = brtWindowTitle:getSize().w         
        local brtWindowWidth_max = math.floor(screen_width / 2)
        if screen_width > screen_height then
            brtWindowWidth_max = math.floor(brtWindowWidth_max * screen_height / screen_width)
        end		
        if statsEnabled and booksReadToday then
            local maxTitleWidth = 0 -- max width of book title string
			local maxStatWidth = 0	-- max width of book stats string
            for i = 1, #booksReadToday[1] do
                local w_title = getWidth(booksReadToday[1][i], w_font.face.it, w_font.size.small)
                if w_title > maxTitleWidth then
                    maxTitleWidth = w_title
                end
                local w_stats = getWidth(booksReadToday[4][i], w_font.face.it, w_font.size.small)
                if w_stats > maxStatWidth then
                    maxStatWidth = w_stats
                end
            end
            if maxTitleWidth > brtWindowWidth then
                brtWindowWidth = math.min((maxTitleWidth), brtWindowWidth_max)
			end
            if maxStatWidth > brtWindowWidth then
                brtWindowWidth = maxStatWidth 	-- max window width is disregarded here because
            end									-- we want stats to stay within one line.	
        end

        -- HELPERS

        local function booksReadTodayEntry(brt_bookTitle, brtStats_str)
            local titleText = brt_bookTitle --string.format("%s", brt_bookTitle)
            local title = textboxx(titleText, w_font.face.it, w_font.size.small, w_font.color.black, brtWindowWidth)

            local brtStats = textt(brtStats_str, w_font.face.it, w_font.size.small, w_font.color.lightGray, 0)

            local w =
                VerticalGroup:new {
                title,
                brtStats
            }
            return w
        end

        -- WINDOW CREATION

        local booksReadTodayWindow = {}
		booksReadTodayWindow =
			VerticalGroup:new {
			brtWindowTitle,
			vertical_spacing()
		}
		if statsEnabled and booksReadToday then
		local brt_separator = textboxx("-", w_font.face.it, w_font.size.small, w_font.color.black, brtWindowWidth)
		brt_separator.forced_height = brtWindowTitle:getSize().h
			for i = 1, #booksReadToday[1] do
				local t = string.lower(booksReadToday[1][i]) -- book title                  
				local statsStr = booksReadToday[4][i]
				booksReadTodayWindow[#booksReadTodayWindow + 1] = booksReadTodayEntry(t, statsStr)
				booksReadTodayWindow[#booksReadTodayWindow + 1] = brt_separator
			end
			table.remove(booksReadTodayWindow) -- removes trailing separator
		elseif not statsEnabled then
			booksReadTodayWindow[#booksReadTodayWindow + 1] =
				textboxx("--", w_font.face.it, w_font.size.small, w_font.color.black, brtWindowWidth)
		else -- if no books read yet
			booksReadTodayWindow[#booksReadTodayWindow + 1] =
				textboxx("nope. :(", w_font.face.it, w_font.size.small, w_font.color.black, brtWindowWidth)
		end

        return booksReadTodayWindow
    end

	--==================//////////==================--

    local frameRadius = Screen:scaleBySize(22)
    local framePadding = w_padding.external

    local WindowToBeDisplayed = nil
    if not self.ui.document then
        WindowToBeDisplayed = buildBooksReadTodayWindow()
        frameRadius = Screen:scaleBySize(10)
    elseif bookCompleted then
        WindowToBeDisplayed = buildBookCompleteWindow()
        frameRadius = Screen:scaleBySize(10)
    elseif not bookCompleted then
        WindowToBeDisplayed = buildQuickLookWindow()
    end

    local final_frame =
        FrameContainer:new {
        radius = frameRadius,
        bordersize = Screen:scaleBySize(2),
        padding = framePadding,
        padding_top = math.floor(w_padding.external / 2.1),
        padding_bottom = math.floor(w_padding.external / 1.1),
        background = Blitbuffer.COLOR_WHITE,
        WindowToBeDisplayed
    }

    self[1] =
        CenterContainer:new {
        dimen = Screen:getSize(),
        VerticalGroup:new {
            final_frame
        }
    }

    -- taps and keypresses

    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = {{Device.input.group.Any}}
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new {
                ges = "swipe",
                range = function()
                    return self.dimen
                end
            }
        }
        self.ges_events.Tap = {
            GestureRange:new {
                ges = "tap",
                range = function()
                    return self.dimen
                end
            }
        }
        self.ges_events.MultiSwipe = {
            GestureRange:new {
                ges = "multiswipe",
                range = function()
                    return self.dimen
                end
            }
        }
    end	
end

function quicklookwindow:onTap()
    UIManager:close(self)
end

function quicklookwindow:onSwipe(arg, ges_ev)
    if ges_ev.direction == "south" then
        -- Allow easier closing with swipe up/down
        self:onClose()
    elseif ges_ev.direction == "east" or ges_ev.direction == "west" or ges_ev.direction == "north" then
        -- -- no use for now
        -- do end -- luacheck: ignore 541
        self:onClose()
    else -- diagonal swipe
        self:onClose()
    end
end

function quicklookwindow:onClose()
    UIManager:close(self)
    return true
end

quicklookwindow.onAnyKeyPressed = quicklookwindow.onClose
quicklookwindow.onMultiSwipe = quicklookwindow.onClose

function quicklookwindow:onShow()
    UIManager:setDirty(
        self,
        function()
            return "ui", self[1][1][1].dimen
        end
    )
    return true
end

function quicklookwindow:onCloseWidget()
    if self[1] and self[1][1] and self[1][1][1] then
        UIManager:setDirty(
            nil,
            function()
                return "ui", self[1][1][1].dimen
            end
        )
    end
end

-- ADD TO DISPATCHER

Dispatcher:registerAction(
    "quicklookbox_action",
    {
        category = "none",
        event = "QuickLook",
        title = _("CVS Receipt"),
        general = true
    }
)

function ReaderUI:onQuickLook()
    if self.statistics then
        self.statistics:insertDB()
    end

    bookCompleted = false

    local widget =
        quicklookwindow:new {
        ui = self,
        document = self.document,
        state = self.view and self.view.state
    }

    UIManager:show(widget, "ui", widget.dimen)
end

function ReaderUI:onEndOfBook()
    if self.statistics then
        self.statistics:insertDB()
    end

    bookCompleted = true

    if showBookCompleteWindow then
        local widget =
            quicklookwindow:new {
            ui = self,
            document = self.document,
            state = self.view and self.view.state
        }

        UIManager:show(widget, "ui", widget.dimen)
    end
end

function FileManager:onQuickLook()
    if self.statistics then
        self.statistics:insertDB()
    end

    local widget =
        quicklookwindow:new {
        ui = self,
        document = self.document,
        state = self.view and self.view.state
    }

    UIManager:show(widget, "ui", widget.dimen)
end

