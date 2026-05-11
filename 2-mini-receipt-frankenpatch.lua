--[[ 2-mini-receipt-frankenpatch.lua ]]
--little box with reading progress markers that can be summoned with a gesture

--[ v1.1.1 ]
--if chapter_page not avail, fall back to (book_page - 1)

local Blitbuffer = require("ffi/blitbuffer")
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
local LineWidget = require("ui/widget/linewidget")
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
local util = require("util")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local _ = require("gettext")
local N_ = _.ngettext

local bookCompleted = false

--GET SETTINGS

local defaults = {
		book_cmpl_wnd = 1,
		serif = 1,
		brt_authors = 1,
		ch_index = 0,
		today_curr_book = 0,
}

local MR_SETT = G_reader_settings:readSetting("mini_rct_sett", defaults)

for k, v in pairs(defaults) do
	if not MR_SETT[k] then 
		MR_SETT[k] = defaults[k]
	end
end

local function writeSettToDisk()
	G_reader_settings:saveSetting("mini_rct_sett", MR_SETT)
end

local function flipSett(value)
	return value == 0 and 1 or 0
end

-- ADD TO MENU

local mini_menu = {  
        text = _("Mini Receipt"),  
        sorting_hint = "tools",  
        sub_item_table = {  
			{  
                text = _("(long press any item for more info)"),
				enabled_func = function () return false end,
            }, 		
			{  
                text = _("show 'book complete' window"),
				help_text = "a little window that pops up when you "..
							"flip past the last page of a book.\n\n"..
							"(set Menu > gear icon > Document > End of document action "..
							"to 'Do nothing' for best results).",
                checked_func = function()  
                    return MR_SETT.book_cmpl_wnd == 1 
                end,  
                callback = function()  
					MR_SETT.book_cmpl_wnd = flipSett(MR_SETT.book_cmpl_wnd)
					writeSettToDisk()
                end,  
            }, 
			{  
                text = _("show authors in 'books read today' window."),  
				help_text = _("shows or hides authors in 'books read today' window."),
                checked_func = function()  
                    return MR_SETT.brt_authors == 1
                end,  
                callback = function()  
					MR_SETT.brt_authors = flipSett(MR_SETT.brt_authors)
					writeSettToDisk()
                end,  
            },			
			{  
                text = _("show chapter index"),  		
				help_text = "CHECKED: chapter field label says 'chapter x of y'\n\n".. 
							"UNCHECKED: chapter field label says 'chapter'.",
                checked_func = function()  
                    return MR_SETT.ch_index == 1
                end,  
                callback = function()  
					MR_SETT.ch_index = flipSett(MR_SETT.ch_index)
					writeSettToDisk()		
                end,  
            }, 
			{  
                text = _("show current book data in 'today'"),  		
				help_text = "CHECKED: 'today' field shows metrics from current book.\n\n"..
							"UNCHECKED: 'today' field shows metrics across all books read today.",
                checked_func = function()  
                    return MR_SETT.today_curr_book == 1
                end,  
                callback = function()  
					MR_SETT.today_curr_book = flipSett(MR_SETT.today_curr_book)
					writeSettToDisk()			
                end,  
            },  			
			{  
                text = _("serif font"),  		
				help_text = "CHECKED: all widgets use 'Noto Serif' font.\n\n".. 
							"UNCHECKED: all widgets use 'Noto Sans' font.",
                checked_func = function()  
                    return MR_SETT.serif == 1  
                end,  
                callback = function()  
					MR_SETT.serif = flipSett(MR_SETT.serif)
					writeSettToDisk()		
                end,  
            },  			
        },  
    }  

if not ReaderFooter._mini_receipt_hooked then
	local og_footer_addToMenu = ReaderFooter.addToMainMenu
	ReaderFooter.addToMainMenu = function(self, menu_items)
		if og_footer_addToMenu then
			og_footer_addToMenu(self, menu_items)
		end
		menu_items.cvs_rct_menu = mini_menu
	end 
	ReaderFooter._mini_receipt_hooked = true
end

local quicklookwindow =
    InputContainer:extend {
    modal = true,
    name = "quick_look_window"
	}

function quicklookwindow:init()
	
    local ReaderStatistics = self.ui.statistics
    local statsEnabled = ReaderStatistics and 
							ReaderStatistics.settings and 
							ReaderStatistics.settings.is_enabled
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
        chapter_page = ReaderToc:getChapterPagesDone(book_page) or book_page - 1 or 0
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
    local w_width = math.floor(math.min(screen_height, screen_width) / 2)

    -- FONT 
	
	local mainFontFace = MR_SETT.serif == 1 and "NotoSerif" or "NotoSans"
    local w_font = {
        face = {
            reg = mainFontFace .. "-Regular.ttf",
            bold = mainFontFace .. "-Bold.ttf",
            it = mainFontFace .. "-Italic.ttf",
            boldit = mainFontFace .. "-BoldItalic.ttf"
        },
        size = {big = 25, med = 18, small = 15, tiny = 13},
        color = {
            black = Blitbuffer.COLOR_BLACK,
            darkGray = Blitbuffer.COLOR_GRAY_1,
            lightGray = Blitbuffer.COLOR_GRAY_4
        }
    }
	
	-- PADDING
	
    local w_padding = {
        internal = Screen:scaleBySize(7),
        external = Screen:scaleBySize(16)
    } -- ext: between frame and widgets, int: verticalspace bw widgets (12)

    -- HELPER FUNCTIONS

    local function secsToTimestring(secs, isCompact) 
		-- convert seconds to 'x hrs y mins' format
		
        if not secs then secs = 0 end
		local timestring = ""

        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
		
		if (h == 0) and (m < 1) then m = 1 end
		
		local h_str, m_str = "", ""
		if isCompact then 
			h_str = T(_("%1h"), h)
			m_str = T(_("%1m"), m)
		else
			h_str = T(N_("1 hr", "%1 hrs", h), h)
			m_str = T(N_("1 min", "%1 mins", m), m)
		end

		if h >= 1 then timestring = timestring .. h_str .. " " end
		if m >= 1 then timestring = timestring .. m_str .. " " end
		timestring = timestring:sub(1, -2) -- remove the last space


        return timestring
    end

    local function vertical_spacing(h) 
		-- vertical space eq. to h*w_padding.internal
		
        if h == nil then
            h = 1
        end
        local s = VerticalSpan:new {width = math.floor(w_padding.internal * h)}
        return s
    end

    local function textt( -- creates TextWidget
						txt, 
						tfont, 
						tsize, 
						tclr, 
						tpadding
						) 
						
        tclr = tclr or w_font.color.black
		
        local w = TextWidget:new {          
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

    local function textboxx( -- creates TextBoxWidget
							txt, 
							tfont, 
							tsize, 
							tclr, 
							twidth, 
							tbold, 
							alignmt
							) 
					
        tclr = tclr or w_font.color.black
        tbold = tbold or false
        alignmt = alignmt or "center"
		
        local w = TextBoxWidget:new {           
					text = txt,
					face = Font:getFace(tfont, tsize),
					fgcolor = tclr,
					bold = tbold,
					width = twidth,
					alignment = alignmt,
					line_height = line_ht
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
	
		-- FILL ALL THE VARIABLES
	
        -- we manually calculate chapter page, chapter total and chapter left in terms of pageturns.
		-- this is because we want progress % to update after every PAGETURN (because that feels more
		-- organic) as opposed to having it update every STABLEPAGE (one single stablepage might spread
		-- across multiple pageturns).
		
		local chapter_pgturn, chapter_pgturn_left, chapter_pgturn_total = 0, 0, 0
		local nextChapterTickPgturn, previousChapterTickPgturn = 0, 0
		
        if self.ui.pagemap and 
		self.ui.pagemap:wantsPageLabels() and 
		ReaderToc then -- if stable pages are ON and toc is available
            nextChapterTickPgturn = ReaderToc:getNextChapter(book_pageturn) or 
									(book_pageturn_total + 1)
			previousChapterTickPgturn = ReaderToc:getPreviousChapter(book_pageturn) or 1
			
			if book_pageturn == 1 or ReaderToc:isChapterStart(book_pageturn) then 
				previousChapterTickPgturn = book_pageturn 
			end
			
			chapter_pgturn = book_pageturn - previousChapterTickPgturn +1
			chapter_pgturn_total = nextChapterTickPgturn - previousChapterTickPgturn
            chapter_pgturn_left = nextChapterTickPgturn - book_pageturn - 1
        else
            chapter_pgturn = chapter_page
			chapter_pgturn_total = chapter_total
			chapter_pgturn_left = chapter_left
        end	
		
		--chapter indices
		local chapter_idx_curr, chapter_idx_total = 0,0
		
		if ReaderToc and MR_SETT.ch_index == 1 then 
			chapter_idx_curr = ReaderToc:getTocIndexByPage(book_pageturn) or 0
			local flat_toc = ReaderToc:getTocTicksFlattened() or {}
			chapter_idx_total = #flat_toc or 0
		end				   															

		-- progress percentages
		
		local prog_pct_book = math.floor((book_pageturn / book_pageturn_total) * 100)
		local prog_pct_chapter = math.floor((chapter_pgturn / chapter_pgturn_total) * 100)

        -- time read today / pages read today

        local timeReadToday, pagesReadToday = 0, 0
        local timeReadToday_str, pagesReadToday_str = "", ""
		
        if statsEnabled and self.ui.document and not bookCompleted then
			if MR_SETT.today_curr_book == 1 then 
				local book_Id = ReaderStatistics.id_curr_book or 0		
				local conn = SQ3.open(db_location)		
				local sql_stmt = [[
					SELECT count(*),
						   sum(sum_duration)
					FROM    (
								 SELECT sum(duration)    AS sum_duration
								 FROM   page_stat
								 WHERE  start_time >= %d
								 AND id_book == %d
								 GROUP BY id_book, page 
							);
				]]
				pagesReadToday, timeReadToday = conn:rowexec(string.format(sql_stmt, ts_midnight_today, book_Id))
				conn:close()		
			else 
				timeReadToday, pagesReadToday = ReaderStatistics:getTodayBookStats() --all books
			end
				timeReadToday = timeReadToday and tonumber(timeReadToday) or 0
				pagesReadToday = pagesReadToday and tonumber(pagesReadToday) or 0

				timeReadToday_str = secsToTimestring(timeReadToday, true)
				pagesReadToday_str = T(N_("1 pg", "%1 pgs", pagesReadToday), pagesReadToday)			
        end

        -- time left in chapter / book

        local function timeLeft_secs(pages)
            local avgTimePerPgturn = 0
            if statsEnabled then
                avgTimePerPgturn = ReaderStatistics.avg_time
            end
            local total_secs = avgTimePerPgturn * pages
            return total_secs
        end

        local timeLeft_book = "calc. time left"
        local timeLeft_chapter = timeLeft_book
        if ReaderStatistics.avg_time and ReaderStatistics.avg_time > 0 then
            timeLeft_book = secsToTimestring(timeLeft_secs(book_pageturn_left + 1), true) .. " left" 
			-- +1 to include current page when calc. time left
			
            timeLeft_chapter = secsToTimestring(timeLeft_secs(chapter_pgturn_left + 1), true) .. " left"
        end

		-- BUILD WIDGETS
		
		local lineClearance = Screen:scaleBySize(10)
		local widgetClearance = vertical_spacing(0.3)
		local titleFontSize = w_font.size.small + 1
		
		-- vertical line helper function
		
		local vertical_line = function(height)
			local line = LineWidget:new{					  
							background = Blitbuffer.COLOR_GRAY,   
							dimen = 
								Geom:new{  
								w = Screen:scaleBySize(1),   
								h = height, 
							},  
			}		
			line = HorizontalGroup:new{				
					HorizontalSpan:new{width = lineClearance},
					line,
					HorizontalSpan:new{width = lineClearance},
			}
			return line
		end
			
		-- book box
		
		local function buildBookBox()
			local wid = w_width * 0.7
			local t = book_title .. " - " .. book_author
			t = string.lower(t)		
			local t_widget = textboxx(
								t, 
								w_font.face.it, 
								titleFontSize, 
								w_font.color.black, 
								wid, 
								nil, 
								"left"
			)			
			local pXofY = "page " .. book_page .. " of " .. book_total
			local pXofY_widget = textboxx(
									pXofY, 
									w_font.face.reg, 
									w_font.size.small, 
									w_font.color.black, 
									wid, 
									nil, 
									"left"
			)
			
			local tleft_font = w_font.face.bold
			local tleft_text = timeLeft_book
			if book_pageturn == book_pageturn_total then 
				tleft_font = w_font.face.boldit
				tleft_text = "fin."
			end
			if not statsEnabled then tleft_text = "--" end
			local bookTLeft_widget = textboxx(
										tleft_text, 
										tleft_font, 
										w_font.size.small,
										w_font.color.black, 
										wid, 
										nil,
										"left"
			)			
			return VerticalGroup:new{
								t_widget,
								widgetClearance,
								pXofY_widget,
								bookTLeft_widget
			}	
		end
			
		local bookBox = buildBookBox()	
		local bookBox_dimen = bookBox:getSize()
		
		-- top separator
		
		local top_separator = vertical_line(bookBox_dimen.h)
		
		-- book percentage box
		
		local function buildBookPctBox()
			local wid = w_width * 0.3
			local pct = prog_pct_book
			--if pct > 0 and pct < 10 then pct = "0" .. pct end
			local pct_textsize = pct == 100 and 45 or
									pct < 10 and 60 or
									55			
			local number = textt(
							pct, 
							w_font.face.reg, 
							pct_textsize, 
							w_font.color.black, 
							0
			)
			local number_dimen = number:getSize()
			
			local pctSymbol = textt(
								"%", 
								w_font.face.reg, 
								w_font.size.small, 
								w_font.color.black, 
								0
			)
			local pctSymbol_dimen = pctSymbol:getSize()
			
			-- baseline matching
			pctSymbol.forced_height = number_dimen.h
			local number_baseline = number:getBaseline()
			local pctSymbol_baseline = pctSymbol:getBaseline()
			local baseline_diff = number_baseline - pctSymbol_baseline
			pctSymbol.forced_baseline = pctSymbol_baseline + baseline_diff
			
			local correction = pct >= 10 and (math.floor(pctSymbol_dimen.w) / 2) or 
								math.floor(pctSymbol_dimen.w)
			
			local numberAndSymbol = HorizontalGroup:new{
										HorizontalSpan:new{width = correction},
										number,
										--HorizontalSpan:new{width = Size.padding.small},
										pctSymbol,
			}
			local numberAndSymbol = CenterContainer:new{
											dimen = Geom:new{w = wid, h = bookBox_dimen.h,},											
											numberAndSymbol,			
			}
			return numberAndSymbol
		end
		local bookPctBox = buildBookPctBox()
		
		-- chapter box
		
		local function buildChapterBox()
			local wid = w_width * 0.7
			chapter_title = string.lower(util.trim(chapter_title))
			if chapter_title == "" then chapter_title = "ツ" end
			
			local t = MR_SETT.ch_index == 1 and 
						string.format("CHAPTER %i OF %i: \n%s", 
										chapter_idx_curr, 
										chapter_idx_total,
										chapter_title) or
										"CHAPTER: " .. chapter_title
						
			local t_widget = textboxx(
								t, 
								w_font.face.it, 
								titleFontSize, 
								w_font.color.black, 
								wid, 
								nil, 
								"left"
			)			
			
			local pXofY = "page " .. chapter_page .. " of " .. chapter_total
			pXofY = T(_("%1 (%2%)"), pXofY, prog_pct_chapter)
			local pXofY_widget = textboxx(
									pXofY, 
									w_font.face.reg, 
									w_font.size.small, 
									w_font.color.black, 
									wid, 
									nil, 
									"left"
			)

			local tleft_font = w_font.face.bold
			local tleft_text = timeLeft_chapter		
			
			if chapter_pgturn == chapter_pgturn_total then 
				tleft_font = w_font.face.boldit
				tleft_text = "fin."
			end			
			
			if not statsEnabled then tleft_text = "--" end				
			local chapterTLeft_widget = textboxx(
											tleft_text, 
											tleft_font, 
											w_font.size.small, 
											w_font.color.black, 
											wid, 
											nil,
											"left"
			)
			
			return VerticalGroup:new{
					t_widget,
					widgetClearance,
					pXofY_widget,
					chapterTLeft_widget
			}	
		end
		local chapterBox = buildChapterBox()
		local chapterBox_dimen = chapterBox:getSize()
		
		local bottom_separator = vertical_line(chapterBox_dimen.h)
		
		-- time read today box
		
		local function buildTimeReadTodayBox()
			local wid = w_width * 0.3
			local t =  T(_("today:\n%1\n%2"), pagesReadToday_str, timeReadToday_str) 
			if not pagesReadToday or pagesReadToday == 0 then 
				t = "today:\nnope. :("
			end
			if not statsEnabled then
				t = "today:\n--"
			end
			local t_widget = textboxx(
								t, 
								w_font.face.reg, 
								w_font.size.small, 
								w_font.color.lightGray, 
								wid, 
								nil, 
								"left"
			)
			
			return VerticalGroup:new{
						t_widget,
						VerticalSpan:new{width = chapterBox_dimen.h - t_widget:getSize().h }
			}
		end
		local timeReadTodayBox = buildTimeReadTodayBox()		
		
		local topHalf = HorizontalGroup:new{					
							bookPctBox,
							top_separator,
							bookBox,
		}											
											
		local horSeparator = VerticalGroup:new{					
								VerticalSpan:new{width = lineClearance},
								LineWidget:new{  
											background = Blitbuffer.COLOR_GRAY,
											dimen = 
													Geom:new{  
														w = w_width + Screen:scaleBySize(1) + lineClearance * 2, 
														h = Screen:scaleBySize(1),
											},  
								},
								VerticalSpan:new{width = lineClearance},
		}
								
		local bottomHalf = HorizontalGroup:new{					
							chapterBox,
							bottom_separator,
							timeReadTodayBox,
		}

        local quickLookWindow = VerticalGroup:new{						
									topHalf,
									horSeparator,
									bottomHalf
		}            

		local final_frame = FrameContainer:new{					
								radius = Screen:scaleBySize(22),
								bordersize = Screen:scaleBySize(2),
								padding = w_padding.external,
								background = Blitbuffer.COLOR_WHITE,
								quickLookWindow
		}
		
		return final_frame
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
		daysAgoTxt = not statsEnabled and "--" or
						daysAgo == 0 and "started today" or
						daysAgo == 1 and "started yesterday" or
						string.format("started %i days ago", daysAgo)

        local bookStartDate = ""
        if statsEnabled then
            bookStartDate = os.date("%d-%m-%Y", tonumber(ts_bookStart))
        end

        local startedOn_str = string.format("%s (%s)", daysAgoTxt, bookStartDate)

        -- BOOK READ TIME / HIGHLIGHT COUNT

        local bookReadTime, bookPagesRead, highlightCount = 0, 0, 0
        if statsEnabled and bookCompleted then
            local pages_placeholder, time_placeholder = ReaderStatistics:getPageTimeTotalStats(ReaderStatistics.id_curr_book)
			bookReadTime = time_placeholder or 0
			bookPagesRead = pages_placeholder or 0
			local ok, stats = pcall(ReaderStatistics.getCurrentStat, ReaderStatistics) 
			if ok and stats and stats[15] then  										
				highlightCount = tonumber(stats[15][2]) or 0  
			end           		
        end

        local bookReadTime_string = ""
        local bookCompleteStats = "--"
        local highlightCount_str = ""
        if statsEnabled then
            highlightCount_str = T(N_("1 highlight", "%1 highlights", highlightCount), highlightCount)
            bookReadTime_string = string.format("read for %s", secsToTimestring(bookReadTime))
            bookCompleteStats = string.format(
									"%s\n%s\n%s", 
									bookReadTime_string, 
									startedOn_str, 
									highlightCount_str
			)
        end

        -- WINDOW WIDTH

        local bcWidgetWidth = 0
        if not statsEnabled then
            bcWidgetWidth = getWidth(
								"book complete!", 
								w_font.face.boldit, 
								w_font.size.med
			)
        else
			local wid1 = getWidth(
							startedOn_str, 
							w_font.face.it, 
							w_font.size.small
			)
			local wid2 = getWidth(
							bookReadTime_string, 
							w_font.face.it, 
							w_font.size.small
			)
			bcWidgetWidth = math.max(wid1, wid2)
		end

        local bookCompleteWindow = {}
        if bookCompleted then
            bookCompleteWindow =
                VerticalGroup:new {
                textboxx(
					"book complete!", 
					w_font.face.boldit, 
					w_font.size.med, 
					w_font.color.black, 
					bcWidgetWidth
				),
                vertical_spacing(0.5),
                textboxx(
					bookCompleteStats, 
					w_font.face.it, 
					w_font.size.small, 
					w_font.color.black, 
					bcWidgetWidth
				)
            }
        end

		local final_frame =
			FrameContainer:new {
			radius = Screen:scaleBySize(10),
			bordersize = Screen:scaleBySize(2),
			padding = w_padding.external,
			padding_top = math.floor(w_padding.external * 0.5),
			padding_bottom = math.floor(w_padding.external * 0.9),
			background = Blitbuffer.COLOR_WHITE,
			bookCompleteWindow
		}
		
		return final_frame
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
												WHERE   page_stat_tbl.id_book=book_tbl.id 
												AND     page_stat_tbl.start_time BETWEEN %d AND %d
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
				if MR_SETT.brt_authors == 1 then -- if authors enabled, then replaces "title" in [1][i] 
												 -- with "title - author(s)"
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
		local brtWindowTitle = textt(
								"books read today", 
								w_font.face.boldit, 
								w_font.size.med, 
								w_font.color.black, 
								0
		)
        local brtWindowWidth = brtWindowTitle:getSize().w         
        local brtWindowWidth_max = math.floor(math.min(screen_width, screen_height) / 2)

        if statsEnabled and booksReadToday then
            local maxTitleWidth = 0 -- max width of book title string
			local maxStatWidth = 0	-- max width of book stats string
            for i = 1, #booksReadToday[1] do
                local w_title = getWidth(
									booksReadToday[1][i], 
									w_font.face.reg, 
									w_font.size.small
				)
                if w_title > maxTitleWidth then
                    maxTitleWidth = w_title
                end
                local w_stats = getWidth(
									booksReadToday[4][i], 
									w_font.face.it, 
									w_font.size.small
				)
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
            local title = textboxx(
							titleText, 
							w_font.face.reg, 
							w_font.size.small,
							w_font.color.black, 
							brtWindowWidth
			)

            local brtStats = textt(
								brtStats_str, 
								w_font.face.it, 
								w_font.size.small, 
								w_font.color.lightGray, 
								0
			)

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
			vertical_spacing(0.7)
		}
		if statsEnabled and booksReadToday then
			local brt_separator = textboxx(
									"-", 
									w_font.face.it, 
									w_font.size.small, 
									w_font.color.black, 
									brtWindowWidth
			)
			brt_separator.forced_height = brtWindowTitle:getSize().h
			for i = 1, #booksReadToday[1] do
				local t = string.lower(booksReadToday[1][i]) -- book title                  
				local statsStr = booksReadToday[4][i]
				booksReadTodayWindow[#booksReadTodayWindow + 1] = booksReadTodayEntry(t, statsStr)
				booksReadTodayWindow[#booksReadTodayWindow + 1] = vertical_spacing()
			end
			table.remove(booksReadTodayWindow) -- removes trailing separator
		elseif not statsEnabled then
			booksReadTodayWindow[#booksReadTodayWindow + 1] =
				textboxx(
					"--", 
					w_font.face.it, 
					w_font.size.small, 
					w_font.color.black, 
					brtWindowWidth
				)
		else -- if no books read yet
			booksReadTodayWindow[#booksReadTodayWindow + 1] =
				textboxx(
					"nope. :(", 
					w_font.face.it, 
					w_font.size.small, 
					w_font.color.black, 
					brtWindowWidth
				)
		end
		
		local final_frame = FrameContainer:new {			
								radius = Screen:scaleBySize(10),
								bordersize = Screen:scaleBySize(2),
								padding = w_padding.external,
								padding_top = math.floor(w_padding.external / 1.5),
								background = Blitbuffer.COLOR_WHITE,
								booksReadTodayWindow
		}
		
		return final_frame
    end

	--==================//////////==================--

    local WindowToBeDisplayed = nil
    if not self.ui.document then
        WindowToBeDisplayed = buildBooksReadTodayWindow()
        frameRadius = Screen:scaleBySize(10)
		padding_top = math.floor(w_padding.external * 0.2)
    elseif bookCompleted then
        WindowToBeDisplayed = buildBookCompleteWindow()
        frameRadius = Screen:scaleBySize(10)
    elseif not bookCompleted then
        WindowToBeDisplayed = buildQuickLookWindow()
    end

    self[1] =
        CenterContainer:new {
        dimen = Screen:getSize(),
        VerticalGroup:new {
            WindowToBeDisplayed
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
        title = _("Mini Receipt"),
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

    if MR_SETT.book_cmpl_wnd == 1 then
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

