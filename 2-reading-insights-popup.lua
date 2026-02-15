--[ reading insights popup v1.0.44 ] 
--cache writes to separate lua file

-- ABOUT:
-- this is a modified version of the 'reading insights popup' userpatch made by u/quanganhdo.
-- (https://github.com/quanganhdo/koreader-user-patches/)
-- this version of the patch modifies the design of the original version, with a few
-- additions here and there.

-- WHAT DOES THIS PATCH DO?
-- shows weekly and monthly reading streaks.
-- shows monthly reading hours or reading days.
-- shows total pages read per year.

-- USAGE:
-- everything except the three big boxes at the top is clickable.
-- touch devices can move between years via swipe or tapping prev/next year.
-- non touch devices can move between years using page turn buttons.
-- all devices can open year selector by tapping or clicking on the current year label.
-- long press on the year label to find options to force reload data.
-- by default, this patch refreshes the displayed data only once per day. all subsequent 
-- changes for the day will be updated on the following day's refresh. if you want to change 
-- this behaviour and have it refresh every time new data is added to the statistics sql, 
-- set the 'refreshOnlyOncePerDay' flag below to 'false'.

local refreshOnlyOncePerDay = true

local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local ButtonDialog = require("frontend/ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local FileManager = require("apps/filemanager/filemanager")
local FocusManager = require("ui/widget/focusmanager")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LuaSettings = require("luasettings")
local logger = require("logger")
local LineWidget = require("ui/widget/linewidget")
local ReaderUI = require("apps/reader/readerui")
local Size = require("ui/size")
local SQ3 = require("lua-ljsqlite3/init")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local Screen = Device.screen
local gettext = require("gettext")
local T = require("ffi/util").template
local util = require("util")

-- User patch localization: add your language overrides here.
local PATCH_L10N = {
    en = {
        ["Jan"] = "Jan",
        ["Feb"] = "Feb",
        ["Mar"] = "Mar",
        ["Apr"] = "Apr",
        ["May"] = "May",
        ["Jun"] = "Jun",
        ["Jul"] = "Jul",
        ["Aug"] = "Aug",
        ["Sep"] = "Sep",
        ["Oct"] = "Oct",
        ["Nov"] = "Nov",
        ["Dec"] = "Dec",
        ["January"] = "January",
        ["February"] = "February",
        ["March"] = "March",
        ["April"] = "April",
        ["May"] = "May",
        ["June"] = "June",
        ["July"] = "July",
        ["August"] = "August",
        ["September"] = "September",
        ["October"] = "October",
        ["November"] = "November",
        ["December"] = "December",
        ["second read"] = "second read",
        ["seconds read"] = "seconds read",
        ["minute read"] = "minute read",
        ["minutes read"] = "minutes read",
        ["hour read"] = "hour read",
        ["hours read"] = "hours read",
		["book"] = "book",
		["books"] = "books",
		["day"] = "day",
		["days"] = "days",
		["daily record"] = "daily record",
        ["day read"] = "day read",
        ["days read"] = "days read",
        ["page read"] = "page read",
        ["pages read"] = "pages read",
		["week"] = "week",
		["weeks"] = "weeks",
		["weekly record"] = "weekly record",
        ["week in a row"] = "week in a row",
        ["weeks in a row"] = "weeks in a row",
        ["day in a row"] = "day in a row",
        ["days in a row"] = "days in a row",
        ["page"] = "page",
        ["pages"] = "pages",
        ["TODAY"] = "TODAY",
        ["No weekly streak"] = "No weekly streak",
        ["No daily streak"] = "No daily streak",
        ["CURRENT STREAK"] = "CURRENT STREAK",
        ["BEST STREAK"] = "BEST STREAK",
        ["DAYS READ PER MONTH"] = "DAYS READ PER MONTH",
        ["HOURS READ PER MONTH"] = "HOURS READ PER MONTH",
        ["Reading statistics: reading insights"] = "Reading statistics: reading insights",
        ["Unknown"] = "Unknown",
        ["No books read"] = "No books read",
        ["No books read in %1"] = "No books read in %1",
        ["No books read in "] = "No books read in ",
        ["%1 - Book Read (%2)"] = "%1 - Book Read (%2)",
        ["%1 - Books Read (%2)"] = "%1 - Books Read (%2)",
    },
    vi = {
        ["Jan"] = "Th1",
        ["Feb"] = "Th2",
        ["Mar"] = "Th3",
        ["Apr"] = "Th4",
        ["May"] = "Th5",
        ["Jun"] = "Th6",
        ["Jul"] = "Th7",
        ["Aug"] = "Th8",
        ["Sep"] = "Th9",
        ["Oct"] = "Th10",
        ["Nov"] = "Th11",
        ["Dec"] = "Th12",
        ["January"] = "Tháng 1",
        ["February"] = "Tháng 2",
        ["March"] = "Tháng 3",
        ["April"] = "Tháng 4",
        ["May"] = "Tháng 5",
        ["June"] = "Tháng 6",
        ["July"] = "Tháng 7",
        ["August"] = "Tháng 8",
        ["September"] = "Tháng 9",
        ["October"] = "Tháng 10",
        ["November"] = "Tháng 11",
        ["December"] = "Tháng 12",
        ["second read"] = "giây đã đọc",
        ["seconds read"] = "giây đã đọc",
        ["minute read"] = "phút đã đọc",
        ["minutes read"] = "phút đã đọc",
        ["hour read"] = "giờ đã đọc",
        ["hours read"] = "giờ đã đọc",
		["book"] = "book",
		["books"] = "books",
		["day"] = "day",
		["days"] = "days",
		["daily record"] = "daily record",
        ["day read"] = "ngày đã đọc",
        ["days read"] = "ngày đã đọc",
        ["page read"] = "trang đã đọc",
        ["pages read"] = "trang đã đọc",
		["week"] = "week",
		["weeks"] = "weeks",
		["weekly record"] = "weekly record",
        ["week in a row"] = "tuần liên tiếp",
        ["weeks in a row"] = "tuần liên tiếp",
        ["day in a row"] = "ngày liên tiếp",
        ["days in a row"] = "ngày liên tiếp",
        ["page"] = "trang",
        ["pages"] = "trang",
        ["TODAY"] = "HÔM NAY",
        ["No weekly streak"] = "Không có chuỗi tuần liên tiếp",
        ["No daily streak"] = "Không có chuỗi ngày liên tiếp",
        ["CURRENT STREAK"] = "CHUỖI LIÊN TIẾP HIỆN TẠI",
        ["BEST STREAK"] = "CHUỖI LIÊN TIẾP DÀI NHẤT",
        ["DAYS READ PER MONTH"] = "SỐ NGÀY ĐỌC MỖI THÁNG",
        ["HOURS READ PER MONTH"] = "SỐ GIỜ ĐỌC MỖI THÁNG",
        ["Reading statistics: reading insights"] = "Thống kê đọc: phân tích",
        ["Unknown"] = "Không rõ",
        ["No books read"] = "Chưa đọc sách nào",
        ["No books read in %1"] = "Không đọc sách nào trong %1",
        ["No books read in "] = "Không đọc sách nào trong ",
        ["%1 - Book Read (%2)"] = "%1 - Sách đã đọc (%2)",
        ["%1 - Books Read (%2)"] = "%1 - Sách đã đọc (%2)",
    },
}

local function l10nLookup(msg)
    local lang = "en"
    if G_reader_settings and G_reader_settings.readSetting then
        lang = G_reader_settings:readSetting("language") or "en"
    end
    local lang_base = lang:match("^([a-z]+)") or lang
    local map = PATCH_L10N[lang] or PATCH_L10N[lang_base] or PATCH_L10N.en or {}
    return map[msg]
end

local function _(msg)
    return l10nLookup(msg) or gettext(msg)
end

local function N_(singular, plural, n)
    local singular_override = l10nLookup(singular)
    local plural_override = l10nLookup(plural)
    if singular_override or plural_override then
        if n == 1 then
            return singular_override or plural_override
        end
        return plural_override or singular_override
    end
    return gettext.ngettext(singular, plural, n)
end

local function formatCount(value)
    if value == nil then return "" end
    return util.getFormattedSize(value)
end

local function formatNumber(value)
    if value == nil then return "" end
    if type(value) == "number" and value % 1 ~= 0 then
        return string.format("%.1f", value)
    end
    return formatCount(value)
end

local MONTH_NAMES_SHORT = {
    _("Jan"), _("Feb"), _("Mar"), _("Apr"), _("May"), _("Jun"),
    _("Jul"), _("Aug"), _("Sep"), _("Oct"), _("Nov"), _("Dec"),
}
local MONTH_NAMES_FULL = {
    _("January"), _("February"), _("March"), _("April"), _("May"), _("June"),
    _("July"), _("August"), _("September"), _("October"), _("November"), _("December"),
}

local db_path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
local ReadingInsightsPopup

local INSIGHTS_MODE_KEY = "reading_insights_popup_mode"
local INSIGHTS_MODE_DAYS = "days"
local INSIGHTS_MODE_HOURS = "hours"

local function normalizeInsightsMode(mode)
    if mode == INSIGHTS_MODE_HOURS then
        return INSIGHTS_MODE_HOURS
    end
    return INSIGHTS_MODE_DAYS
end

local function readInsightsMode()
    if G_reader_settings and G_reader_settings.readSetting then
        return normalizeInsightsMode(G_reader_settings:readSetting(INSIGHTS_MODE_KEY, INSIGHTS_MODE_DAYS))
    end
    return INSIGHTS_MODE_DAYS
end

local function saveInsightsMode(mode)
    if G_reader_settings and G_reader_settings.saveSetting then
        G_reader_settings:saveSetting(INSIGHTS_MODE_KEY, mode)
    end
end
--ON DISK

local database_file = DataStorage:getDataDir() .. "/reading_insights_data.lua"
local ReadingInsightsDatabase = LuaSettings:open(database_file)

--CACHE
local insightsCache = ReadingInsightsDatabase:readSetting("readingInsights_cache") or {
				streaks = nil,
				yearRange = nil,
				yearlyStats = nil,
				monthlyReadingDays = nil,
				monthlyReadingHours = nil,
}
local cache_timestamps = ReadingInsightsDatabase:readSetting("readingInsights_cacheTimestamps") or { 
				partialClear = 1262304000,	-- last local db update aka cache partially cleared (pulled from lfs)
				fullClear = 1262304000, 	-- cached stats sync timestamp aka cache fully cleared (recorded via stats plugin patch)
				statsSynced = 1262304000,	-- latest stats sync timestamp (recorded via stats plugin patch)
				lastRefreshed = 1262304000,	-- latest cache modified timestamp (recorded bwith os.time(), used to 
											-- manage refreshOnlyOncePerDay)
}
local cachedLayout = nil
local function writeCacheTimestampsToDisk()
	ReadingInsightsDatabase:saveSetting("readingInsights_cacheTimestamps", cache_timestamps)
	ReadingInsightsDatabase:flush()
end
local function writeInsightsCacheToDisk(item)
	logger.info("READING-INSIGHTS-POPUP: UPLOADING CACHE: ", item)
	ReadingInsightsDatabase:saveSetting("readingInsights_cache", insightsCache)
	ReadingInsightsDatabase:flush()
end
local function set_cache_partialClear_timestamp(timestamp)
	cache_timestamps.partialClear = timestamp
	writeCacheTimestampsToDisk()
end
local function set_cache_fullClear_timestamp(timestamp)
	cache_timestamps.fullClear = timestamp
	writeCacheTimestampsToDisk()
end
local function getDbModTime() 
	--finds out when stats sql was last modified.
	
    local lfs = require("libs/libkoreader-lfs")  
    local attr = lfs.attributes(db_path, "modification")  
    return attr and attr or 0  
end  

local function clearCache(year)		
	if year then 
		logger.info("READING-INSIGHTS-POPUP: ERASING CACHE FOR YEAR", year)
		insightsCache.streaks = nil
		insightsCache.yearRange = nil		
		insightsCache.yearlyStats = insightsCache.yearlyStats or {}
		insightsCache.yearlyStats[year] = nil
		insightsCache.monthlyReadingDays = insightsCache.monthlyReadingDays or {}
		insightsCache.monthlyReadingDays[year] = nil
		insightsCache.monthlyReadingHours = insightsCache.monthlyReadingHours or {}
		insightsCache.monthlyReadingHours[year] = nil
	else
		logger.info("READING-INSIGHTS-POPUP: ERASING ALL CACHED DATA")
		insightsCache = {}
	end
end

local function clearCacheIfRequired() -- checks and calls clearCache() as per req.
    local ts_now = os.time()
    local t = os.date("*t", ts_now)
    t.hour = 0
    t.min = 0
    t.sec = 0
    local ts_midnight_today = os.time(t)
	
    latest_db_mod_timestamp = getDbModTime() 

	if refreshOnlyOncePerDay and (cache_timestamps.lastRefreshed > ts_midnight_today) then return end	
	
	if (cache_timestamps.statsSynced > cache_timestamps.fullClear) then --if stats db was modified via sync		
		set_cache_fullClear_timestamp(cache_timestamps.statsSynced)
		set_cache_partialClear_timestamp(latest_db_mod_timestamp)
		cache_timestamps.lastRefreshed = ts_now
		return clearCache()	
	end
	
	if (latest_db_mod_timestamp > cache_timestamps.partialClear) then --if stats db was modified locally		
		for i = tonumber(os.date("%Y", cache_timestamps.partialClear)), tonumber(os.date("%Y", latest_db_mod_timestamp)) do
			clearCache(i)
		end	
		cache_timestamps.lastRefreshed = ts_now
		return set_cache_partialClear_timestamp(latest_db_mod_timestamp)
    end  
	
	if latest_db_mod_timestamp < (ts_midnight_today - 86400) and 	--if stats db was last modified more than two midnights ago and
		(insightsCache.streaks.current_days) and 					--current day streak hasn't been reset to 0
		(insightsCache.streaks.current_days ~= 0) then 				
			logger.info("READING-INSIGHTS-POPUP: CLEARING CACHED STREAKS")
			insightsCache.streaks = nil
	end
end

--FALLBACK ARRAY
local fallback_monthlyData = {}

for month_num = 1, 12 do
	table.insert(fallback_monthlyData, {
		month = "--",
		days = 0,
		hours = 0,
		label = MONTH_NAMES_SHORT[month_num],
		label_full = MONTH_NAMES_FULL[month_num],
	})
end
local fallbackTable = {
	streaks = {
				days = 	{
							current = 0,
							best = 0,
							best_start = 1,
							best_end = 1,							
						},
				weeks = {
							current = 0,
							best = 0,
							best_start = 1,
							best_end = 1,								
						},
    },
	yearRange = { min_year = 0000, max_year = 0000 },
	yearlyStats = { days = 0, pages = 0, duration = 0 },
	monthlyReadingDays = fallback_monthlyData,
	monthlyReadingHours = fallback_monthlyData,
	isPlaceholder = true
}

local function withStatsDb(fallback, fn)
    local lfs = require("libs/libkoreader-lfs")
    if lfs.attributes(db_path, "mode") ~= "file" then
        return fallback
    end

    local conn = SQ3.open(db_path)
    if not conn then return fallback end

    local ok, result = pcall(fn, conn)
    conn:close()
    if ok then
        return result
    end
    return fallback
end

local function withStatement(conn, sql, fn)
    local stmt = conn:prepare(sql)
    if not stmt then return end
    local ok, result = pcall(fn, stmt)
    stmt:close()
    if ok then
        return result
    end
end

local function computeStreaks(entries_desc, is_consecutive, is_current_start, weeksOrDays)
	local a = {
				current = 0,
				best = 0,
				best_start = 0,
				best_end = 0,							
	}
    if #entries_desc == 0 then
        return a
	elseif #entries_desc == 1 then
		a.best = 1
		if is_current_start(entries_desc[1][1]) then 
			a.current = 1 			
		end
		return a
    end
	a = nil

    local current = 0
    if is_current_start(entries_desc[1][1]) then
        current = 1
        for i = 2, #entries_desc do
            if is_consecutive(entries_desc[i - 1][1], entries_desc[i][1]) then
                current = current + 1
            else
                break
            end
        end
    end

    local best = 1
    local run = 1
	local best_start = 0
	local best_end = 0
	local best_end_temp = 0 --temporary
    for i = 2, #entries_desc do
        if is_consecutive(entries_desc[i - 1][1], entries_desc[i][1]) then
			if run == 1 then best_end_temp = (i - 1) end
            run = run + 1
            if run > best then
                best = run
				best_start = i
				best_end = best_end_temp
            end
        else
            run = 1
        end
    end
	
	if weeksOrDays == 1 then -- days
		best_start = tonumber(entries_desc[best_start][2])
		best_end = tonumber(entries_desc[best_end][2])
	else
		best_start = tonumber(entries_desc[best_start][1]) 	--first timestamp of first week
		best_end = tonumber(entries_desc[best_end][2])		--last timestamp of last week
	end
	
	return{
		current = current,
		best = best,
		best_start = best_start,
		best_end = best_end,							
	}
end

local function parseDateYMD(date_str)
    if not date_str then return end
    local year = tonumber(date_str:sub(1,4))
    local month = tonumber(date_str:sub(6,7))
    local day = tonumber(date_str:sub(9,10))
    if not year or not month or not day then return end
    return year, month, day
end

local function parseWeekYear(week_stamp)
    if not week_stamp then return end
    local year_week = os.date("%G-%V", week_stamp)
    return year_week
end

local function formatHoursRead(seconds)
	local value = 0
	local unit = ""
	
	if (not seconds) or (seconds < 60) then 
		return 0, "hours read"
	end
	
	local h = math.floor(seconds / 3600)
	local h_unit = N_("hour read", "hours read", h)
	
	if h == 0 then 
		h = math.floor((seconds / 3600) * 10) / 10
		return h, "hours read"
	end
	
	return h, h_unit	
end

local function buildSerifFonts()
		return {
			section = Font:getFace("NotoSans-Regular.ttf", 22),	
			value = Font:getFace("NotoSans-Bold.ttf", 32),
			label = Font:getFace("NotoSans-Regular.ttf", 20),
			small = Font:getFace("NotoSans-Regular.ttf", 18),
			streakValue = Font:getFace("NotoSerif-Regular.ttf", 57),
			streakLabel = Font:getFace("NotoSans-Regular.ttf", 17),
			streaRecordValue = Font:getFace("NotoSerif-Regular.ttf", 22),
			streakStartEndWidget = Font:getFace("NotoSans-Regular.ttf", 10),
		}	
end

local function buildLayout(max_widget_width, padding_h, column_gap)
    local content_width = max_widget_width - 2 * padding_h
    local col_width = math.floor((max_widget_width - Size.line.medium) / 2 ) - Screen:scaleBySize(2)
    local a =  {
        full_width = max_widget_width,
        padding_h = padding_h,
        column_gap = column_gap,
        content_width = content_width,
        col_width = col_width,
    }
	cachedLayout = a
	return a
end

local function buildColumnSeparator(height)
    local v_padding = Size.padding.default
    return VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ height = v_padding },
            LineWidget:new{
                dimen = Geom:new{ w = Size.line.medium, h = height - 2 * v_padding },
                background = Blitbuffer.COLOR_GRAY,
            },
            VerticalSpan:new{ height = v_padding },
        }
end

local function buildValueLine(font_value, font_label, column_gap, value, unit)
    local value_widget = TextWidget:new{ text = value, face = font_value }
    local value_dimen = value_widget:getSize()
	local unit_widget = TextWidget:new{
							text = unit,
							face = font_label,
	}
	
	-- -- match baselines
	-- unit_widget.forced_height = value_dimen.h
	-- local value_baseline = value_widget:getBaseline()
	-- local unit_baseline = unit_widget:getBaseline()
	-- local baseline_diff = value_baseline - unit_baseline
	-- unit_widget.forced_baseline = unit_baseline + baseline_diff
	
    return HorizontalGroup:new{
        HorizontalSpan:new{ width = column_gap },		
        value_widget,
        HorizontalSpan:new{ width = Size.padding.large },
		unit_widget,
    }
end

local function buildYearHeader(popup_self, font_section, layout, yearRange)
    local selected_year = popup_self.selected_year
    local prev_enabled = selected_year > yearRange.min_year
    local next_enabled = selected_year < yearRange.max_year
	

    local sample_nav = TextWidget:new{ text = "0000", face = font_section }
	local icon_width = Screen:scaleBySize(15)
    local nav_width = sample_nav:getSize().w + icon_width
    sample_nav:free()
	
	local year_button_tap_dialog
	local tap_buttons = {}	
	local yearCount = popup_self.yearRange.max_year - popup_self.yearRange.min_year
	if yearCount >= 1 then
		for i = popup_self.yearRange.min_year, popup_self.yearRange.max_year do 
			local a = {					
						text = i,
						callback = function() 
							UIManager:close(year_button_tap_dialog)
							popup_self:onGoToPrevYear(popup_self, i) 
						end,
			}
					
			table.insert(tap_buttons, {a})	
		end	
	end

	year_button_tap_dialog = ButtonDialog:new{
		    shrink_unneeded_width = true,
			modal = true,
			buttons = tap_buttons
	}		
	year_button_tap_dialog.onCloseWidget = function(self)  
		UIManager:setDirty(nil, function()  
			return "ui", self.movable.dimen  
		end)  
	end 
	
	local hold_buttons = {
							{
								{
									text = "Check for new stats",
									align = "left",
									callback = function() 
										UIManager:close(year_button_hold_dialog)
										local orig_refreshOnlyOncePerDay = refreshOnlyOncePerDay
										refreshOnlyOncePerDay = false
										clearCacheIfRequired()
										refreshOnlyOncePerDay = orig_refreshOnlyOncePerDay
										popup_self:onGoToPrevYear(popup_self, popup_self.selected_year) 
										return true
									end,
								},
							},
							{
								{
									text = "Force reload streaks",
									align = "left",
									callback = function() 
										local confirm = ConfirmBox:new{
												text = _("Reload streaks?"),
												ok_text = _("Reload"),
												cancel_text = _("Cancel"),
												ok_callback = function()
													UIManager:close(year_button_hold_dialog)
													insightsCache.streaks = nil
													popup_self:onGoToPrevYear(popup_self, popup_self.selected_year)
												end,
										}										
										return UIManager:show(confirm)
									end,
								},
							},
							{
								{
									text = "Force reload " .. popup_self.selected_year .. " insights",
									align = "left",
									callback = function() 
										local confirm = ConfirmBox:new{
												text = _("Reload " .. popup_self.selected_year .. " insights?"),
												ok_text = _("Reload"),
												cancel_text = _("Cancel"),
												ok_callback = function()
													UIManager:close(year_button_hold_dialog)
													clearCache(popup_self.selected_year)
													popup_self:onGoToPrevYear(popup_self, popup_self.selected_year)		
												end,
										}										
										return UIManager:show(confirm) 
									end,
								},
							},
							{
								{
									text = "Force reload all insights",
									align = "left",
									callback = function() 
										local confirm = ConfirmBox:new{
												text = _("Reload all insights?"),
												ok_text = _("Reload"),
												cancel_text = _("Cancel"),
												ok_callback = function()
													UIManager:close(year_button_hold_dialog)
													clearCache()
													popup_self:onGoToPrevYear(popup_self, popup_self.selected_year)
												end,
										}										
										return UIManager:show(confirm)
									end,
								},
							},
	
	}
	
	year_button_hold_dialog = ButtonDialog:new{
		    shrink_unneeded_width = true,
			modal = true,
			buttons = hold_buttons
	}		
	year_button_hold_dialog.onCloseWidget = function(self)  
		UIManager:setDirty(nil, function()  
			return "ui", self.movable.dimen  
		end)  
	end 
	
    local year_label = TextWidget:new{
        text = tostring(selected_year),
        face = font_section,
    }
	year_label = HorizontalGroup:new{
		HorizontalSpan:new{width = Size.padding.large},
		year_label,
		HorizontalSpan:new{width = Size.padding.large},		
	}
	year_label = FrameContainer:new{
		bordersize = Screen:scaleBySize(1),  
		color = Blitbuffer.COLOR_GRAY_E,
		radius = Screen:scaleBySize(7),
		margin = 0,  
		padding = 0,  
		focusable = true,  
		focus_border_size = Screen:scaleBySize(1),  
		focus_border_color = Blitbuffer.COLOR_BLACK, 
		year_label
	}
	local year_dimen = year_label:getSize()	
	local tappable_year_label = InputContainer:new{
		dimen = Geom:new{ w = year_dimen.w, h = year_dimen.h },
		year_label,
		focusable = true,
	}	
    tappable_year_label.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return tappable_year_label.dimen end,
            }
        },
        Hold = {
            GestureRange:new{
                ges = "hold",
                range = function() return tappable_year_label.dimen end,
            }
        },
    }
    function tappable_year_label:onTap()
		if yearCount >= 1 then
			UIManager:show(year_button_tap_dialog, "ui")
		end
		return true
    end	
    function tappable_year_label:onHold()
		UIManager:show(year_button_hold_dialog)
    end	
	
	--FocusManager
	table.insert(popup_self.layout, 1,  tappable_year_label)

    local function navButton(text, target_year, prevOrNext)	
        local text_button = Button:new{
            text = text,
            bordersize = 0,
            padding = 0,
            margin = 0,
            background = Blitbuffer.COLOR_GRAY_E,
            text_font_face = font_section.orig_font,
            text_font_size = font_section.orig_size,
            text_font_bold = false,
			focusable = true,
            callback = function()
                if prevOrNext == 0 then 
					popup_self:onGoToPrevYear(popup_self)
				else 
					popup_self:onGoToNextYear(popup_self)
				end
            end,
        }
		local function getLeftIcon()
			return IconWidget:new{
				icon = "chevron.left",
				width = icon_width,
				alpha = true,
				is_icon = true,
			}
		end
		local function getRightIcon()
			return IconWidget:new{
				icon = "chevron.right",
				width = icon_width,
				alpha = true,
				is_icon = true,
			}
		end
		if prevOrNext == 0 then 
			return HorizontalGroup:new{getLeftIcon(), text_button}
		else 
			return HorizontalGroup:new{text_button, getRightIcon()}
		end
    end

    local prev_widget = prev_enabled
        and navButton(tostring(selected_year - 1), selected_year - 1, 0)
        or HorizontalSpan:new{ width = nav_width }
    local next_widget = next_enabled
        and navButton(tostring(selected_year + 1), selected_year + 1, 1)
        or HorizontalSpan:new{ width = nav_width }

    local prev_w = prev_enabled and prev_widget:getSize().w or nav_width
    local next_w = next_enabled and next_widget:getSize().w or nav_width
    local remaining = layout.full_width - prev_w - year_dimen.w - next_w - 2 * Size.padding.large - Screen:scaleBySize(2)
    local side_space = math.floor(remaining / 2)

    local year_header_content = HorizontalGroup:new{
        align = "center",
		HorizontalSpan:new{width = Size.padding.large},
        LeftContainer:new{
            dimen = Geom:new{ w = prev_w + side_space, h = year_label:getSize().h },
            prev_widget,
        },
        tappable_year_label,
        LeftContainer:new{
            dimen = Geom:new{ w = next_w + side_space, h = year_label:getSize().h },
            HorizontalGroup:new{
                HorizontalSpan:new{ width = side_space },
                next_widget,
            },
        },
		HorizontalSpan:new{width = Size.padding.large},
    }

    return FrameContainer:new{
        background = Blitbuffer.COLOR_GRAY_E,
		color = Blitbuffer.COLOR_GRAY_E,
        bordersize = Screen:scaleBySize(1),
		radius = Screen:scaleBySize(7),
		padding = 0,
		padding_bottom = Screen:scaleBySize(2),
		margin = 0,
        year_header_content,
    }	
end

local function buildYearlyRow(popup_self, yearly_stats, fonts, layout)
    local left_value = ""
    local left_unit = ""
    if popup_self.mode == INSIGHTS_MODE_HOURS then
        left_value, left_unit = formatHoursRead(yearly_stats.duration)
    else
        left_value = formatCount(yearly_stats.days)
        left_unit = N_("day read", "days read", yearly_stats.days)
    end
    local left_line = buildValueLine(
        fonts.value,
        fonts.streakLabel,
        layout.column_gap,
        left_value,
        left_unit
    )
	local left_line_dimen = left_line:getSize()
    local pages_val = buildValueLine(
        fonts.value,
        fonts.streakLabel,
        layout.column_gap,
        formatCount(yearly_stats.pages),
        N_("page read", "pages read", yearly_stats.pages)
    )
	local pages_val_dimen = pages_val:getSize()

    local selected_year_for_tap = popup_self.selected_year

	--FocusManager	
	local left_focusable = FrameContainer:new{  
				bordersize = Screen:scaleBySize(1),
				radius = Screen:scaleBySize(7),				
				color = Blitbuffer.COLOR_WHITE,
				--dimen = Geom:new{ w = layout.col_width, h = left_line_dimen.h + 2 },
				margin = 0,  
				padding = 0,  
				focusable = true,  
				focus_border_size = Screen:scaleBySize(1),  
				focus_border_color = Blitbuffer.COLOR_BLACK, 
				LeftContainer:new{
					dimen = Geom:new{ w = layout.col_width, h = left_line_dimen.h + 2 },
					left_line,
				}
    }  	
	local left_focusable_dimen = left_focusable:getSize()
    local left_cell = InputContainer:new{  
        dimen = Geom:new{ w = left_focusable_dimen.w, h = left_focusable_dimen.h + 2 },  
        left_focusable,  
    }  	
    left_cell.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return left_cell.dimen end,
            }
        }, 		
    }
    function left_cell:onTap()
        popup_self:toggleInsightsMode(popup_self)
        return true
    end

	--FocusManager
    local right_focusable = FrameContainer:new{  
		bordersize = 1,  
		radius = Screen:scaleBySize(7),
		color = Blitbuffer.COLOR_WHITE,
		margin = 0,  
        padding = 0,  
        focusable = true,  
        focus_border_size = 1,  
        focus_border_color = Blitbuffer.COLOR_BLACK,  
		LeftContainer:new{
				dimen = Geom:new{ w = layout.col_width, h = pages_val_dimen.h + 2 },
				pages_val, 
		}
    } 
	local right_focusable_dimen = left_focusable:getSize()	
    local right_cell = InputContainer:new{  
        dimen = Geom:new{ w = right_focusable_dimen.w, h = right_focusable:getSize().h + 2 },  
        right_focusable,  
    }	
    right_cell.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return right_cell.dimen end,
            }
        },
    }
    function right_cell:onTap()
        popup_self:showBooksForYear(selected_year_for_tap)
        return true
    end
	
	--FocusManager
	local foc_mgr_secondRow = {}
	table.insert(foc_mgr_secondRow, left_cell)
	table.insert(foc_mgr_secondRow, right_cell)
	table.insert(popup_self.layout , foc_mgr_secondRow)		
	
	local columnSeparator = buildColumnSeparator(left_focusable_dimen.h)

    --local yearly_row = buildTwoColRow(left_cell, right_cell, layout)
	
	local yearly_row = HorizontalGroup:new{
						left_cell,
						columnSeparator,
						right_cell,				
	}
		
    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        yearly_row,
    }
end

local function buildMonthlyChart(popup_self, monthly_data, layout, fonts)
    if #monthly_data == 0 then
        return nil
    end

    local value_key = popup_self.mode == INSIGHTS_MODE_HOURS and "hours" or "days"
    local max_value = 1
    for _, m in ipairs(monthly_data) do
        local v = tonumber(m[value_key]) or 0
        if v > max_value then max_value = v end
    end

    local chart_width = layout.content_width
    local bar_height = tonumber(Screen:scaleBySize(60))
    local bar_width = math.floor(chart_width / 6) - tonumber(Screen:scaleBySize(8))
    local bar_gap = math.floor((chart_width - bar_width * 6) / 5)
    local font_small = fonts.small

    local sample_label = TextWidget:new{ text = "0", face = font_small }
    local label_height = sample_label:getSize().h
    sample_label:free()

    local current_year = tonumber(os.date("%Y"))
    local current_month = os.date("%Y-%m")	
			
    local function createBarRow(data_slice)
        local bars_row = HorizontalGroup:new{ align = "bottom" }
        local month_labels_row = HorizontalGroup:new{ align = "top" }
        local baseline_h = Size.line.medium
        local total_bar_height = bar_height + label_height

        for i, m in ipairs(data_slice) do
            local value = tonumber(m[value_key]) or 0
            local ratio = max_value > 0 and (value / max_value) or 0
            local bar_h = math.floor(ratio * bar_height + 0.5)
            if bar_h == 0 and value > 0 then bar_h = 1 end

            local is_current = (popup_self.selected_year == current_year) and (m.month == current_month)
            local bar_color = is_current and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_GRAY

            local value_label = TextWidget:new{
                text = formatNumber(value),
                face = font_small,
            }
            local centered_label = CenterContainer:new{
                dimen = Geom:new{ w = bar_width, h = label_height },
                value_label,
            }

            local bar_column = VerticalGroup:new{
                align = "center",
            }
            table.insert(bar_column, centered_label)
            if bar_h > 0 then
                table.insert(bar_column, LineWidget:new{
                    dimen = Geom:new{ w = bar_width, h = bar_h },
                    background = bar_color,
                })
            end
            table.insert(bar_column, LineWidget:new{
                dimen = Geom:new{ w = bar_width, h = baseline_h },
                background = bar_color,
            })

            local bar_container = BottomContainer:new{
                dimen = Geom:new{ w = bar_width, h = total_bar_height },
                bar_column,
            }
			
			local focusable_bar = FrameContainer:new{  
						bordersize = 1,  
						color = Blitbuffer.COLOR_WHITE,
						margin = 0,  
						padding = 0,  
						focus_border_size = 1,  
						focus_border_color = Blitbuffer.COLOR_BLACK, 
						bar_container,  
						focusable = true,
			}  
			
            local tappable_bar = InputContainer:new{
                dimen = Geom:new{ w = bar_width, h = total_bar_height },
                focusable_bar,
            }
            local month_data = m
            local month_year_label = m.label_full .. " " .. popup_self.selected_year
            tappable_bar.ges_events = {
                Tap = {
                    GestureRange:new{
                        ges = "tap",
                        range = function() return tappable_bar.dimen end,
                    }
                },
            }
            function tappable_bar:onTap()
                popup_self:showBooksForMonth(month_data.month, month_year_label)
                return true
            end			

            table.insert(bars_row, tappable_bar)

            local month_label_widget = TextWidget:new{
                text = string.lower(_(m.label)),
                face = font_small,
            }
            table.insert(month_labels_row, CenterContainer:new{
                dimen = Geom:new{ w = bar_width, h = month_label_widget:getSize().h },
                month_label_widget,
            })

            if i < #data_slice then
                table.insert(bars_row, HorizontalSpan:new{ width = bar_gap })
                table.insert(month_labels_row, HorizontalSpan:new{ width = bar_gap })
            end
        end
			
        return VerticalGroup:new{
            align = "center",
            bars_row,
            VerticalSpan:new{ height = Size.padding.small },
            month_labels_row,
        }
    end
	
	--FocusManager		
	local foc_mgr_thirdRow = {}
	local foc_mgr_fourthRow = {}
	
    local chart = VerticalGroup:new{
        align = "center",
    }
    local row_index = 0
    for i = 1, #monthly_data, 6 do
        local row_data = {}	
		local nonZeroMonths = {} --FocusManager
        for j = i, math.min(i + 5, #monthly_data) do
            table.insert(row_data, monthly_data[j])	

			--FocusManager
			--we only want to add months with non zero values to FocusManager
			local target_value = popup_self.mode == INSIGHTS_MODE_HOURS and "hours" or "days"			
			if monthly_data[j][target_value] ~= 0 then 
				table.insert(nonZeroMonths, j)
			end
        end
        if #row_data > 0 then
            if row_index > 0 then
                table.insert(chart, VerticalSpan:new{ height = Size.padding.default })
            end
			local bar_row = createBarRow(row_data)
			
			--FocusManager
			for idx, month_num in ipairs(nonZeroMonths) do		
				if month_num <=6 then
					month_num = (month_num * 2) - 1 --because bar_row has HorizontalSpan widgets b/w each bar
					table.insert(foc_mgr_thirdRow, bar_row[1][month_num])
				else
					month_num = ((month_num - 6) * 2) - 1
					table.insert(foc_mgr_fourthRow, bar_row[1][month_num])
				end
			end
			
            table.insert(chart, bar_row)
            row_index = row_index + 1
        end
    end
	
	--FocusManager
	if #foc_mgr_thirdRow > 0 then table.insert(popup_self.layout, foc_mgr_thirdRow) end
	if #foc_mgr_fourthRow > 0 then table.insert(popup_self.layout, foc_mgr_fourthRow) end

    return chart
end

local function buildCurrentStreakWidget(streaks_dimen, value, weeksOrDays, fonts, streaks_colors)

	local heading_text = weeksOrDays == 0 and _("weeks in a row") or _("days in a row")
	local heading_text_widget = TextWidget:new{
								text = heading_text,
								padding = 0,
								face = fonts.streakLabel,
								fgcolor = weeksOrDays == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,	
	}
	local value_widget = TextWidget:new{
								text = value,
								padding = 0,
								face = fonts.streakValue,
								fgcolor = weeksOrDays == 0 and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,	
	}
	
	local boxContents = VerticalGroup:new{
							heading_text_widget,
							value_widget,	
	}
	
	return FrameContainer:new{
			padding = 0,
			bordersize = Screen:scaleBySize(1),
			margin = 0,
			color = weeksOrDays == 0 and streaks_colors.darkGray or streaks_colors.lightGray,
			background = weeksOrDays == 0 and streaks_colors.darkGray or streaks_colors.lightGray,
			radius = Screen:scaleBySize(7),
			CenterContainer:new{
                dimen = Geom:new{ w = streaks_dimen.box_width, h = streaks_dimen.box_height },
				boxContents,
			}
	}
end

local function buildBestStreakWidget(streaks, streaks_dimen, fonts, streaks_colors)

	local function buildBestModule(value, weekOrDay, isLongest, ts_start, ts_end)
		local heading_text = weekOrDay == 0 and _("weekly record") or _("daily record") 
		if isLongest then heading_text = heading_text .. " ★" end
		local heading_text_widget = TextBoxWidget:new{
								width = streaks_dimen.box_width - Screen:scaleBySize(10),
								padding = 0,
								text = heading_text,
								face = fonts.streakLabel,
								fgcolor = streaks_colors.midGray,
		}
		
		local value_text = weekOrDay == 0 and N_("week", "weeks", streaks.weeks.best) or N_("day", "days", streaks.days.best)		
		local value_text = value .. " " .. value_text
		local value_widget = TextBoxWidget:new{
									width = streaks_dimen.box_width - Screen:scaleBySize(10),
									padding = 0,
									line_height = 0,
									text = value_text,
									face = fonts.streaRecordValue,
									fgcolor = streaks_colors.black,	
		}		
		
		local widget = VerticalGroup:new{
					heading_text_widget,
					VerticalSpan:new{width = -Screen:scaleBySize(3)},
					value_widget,
		} 
		
		if  (value > 1 and ts_start and ts_end) or (ts_start >= 1 and ts_end >=1)then 
			local startDay =  os.date("%-d " .._(os.date("%b", ts_start)) .. " '%y", ts_start)
			local endDay = os.date("%-d " .._(os.date("%b", ts_end)) .. " '%y", ts_end)
			local startEndWidget_txt = string.upper(startDay .. " - " .. endDay)
			local startEndWidget = TextBoxWidget:new{
									width = streaks_dimen.box_width - Screen:scaleBySize(10),
									padding = 0,
									text = startEndWidget_txt,
									face = fonts.streakStartEndWidget,
									fgcolor = streaks_colors.black,
			}
			
			table.insert(widget, startEndWidget)
		end
		
		return widget
	end
	
	-- for adding "*" if currently on the longest streak
	local isLongest_w = (streaks.weeks.best > 1) and (streaks.weeks.best == streaks.weeks.current) and true or false	
	local isLongest_d = (streaks.days.best > 1) and (streaks.days.best == streaks.days.current) and true or false	
	
	local bestBlock = VerticalGroup:new{
							buildBestModule(streaks.weeks.best, 0, isLongest_w, streaks.weeks.best_start, streaks.weeks.best_end),
							VerticalSpan:new{width = Screen:scaleBySize(5)},
							buildBestModule(streaks.days.best, 1, isLongest_d, streaks.days.best_start, streaks.days.best_end),
	}
	
	local bestBlock_dimen = bestBlock:getSize()
	if bestBlock_dimen.h > streaks_dimen.box_height then 
		streaks_dimen.box_height = bestBlock_dimen.h + Screen:scaleBySize(6)
	end
	
	return FrameContainer:new{
			padding = 0,
			bordersize = Screen:scaleBySize(1),
			margin = 0,
			color = streaks_colors.midGray,
			radius = Screen:scaleBySize(7),
			CenterContainer:new{
                dimen = Geom:new{ w = streaks_dimen.box_width, h = streaks_dimen.box_height },
				HorizontalGroup:new{
					HorizontalSpan:new{width = Screen:scaleBySize(9)},
					bestBlock
				},
			}
	}

end

local function buildInsightsSections(popup_self, streaks, yearly_stats, yearRange, monthly_data, fonts, layout, year)	
	--FocusManager
	popup_self.layout = {} 
	
    local sections = VerticalGroup:new{
        align = "left",
    }
	
	-- STREAKS	
	local streakBoxWidth = math.floor((layout.full_width - (2 * Size.padding.large) - 3*Screen:scaleBySize(2))/3)
	local streaks_dimen = {
				box_width = streakBoxWidth,
				box_height =  streakBoxWidth,	
	}
	local streaks_colors = {
					lightGray = Blitbuffer.COLOR_GRAY_E,
					darkGray = Blitbuffer.COLOR_GRAY_4,
					midGray = Blitbuffer.COLOR_GRAY_7,
					black = Blitbuffer.COLOR_BLACK,
	}	
	
	local maxCurrentStreak = math.max(streaks.days.current, streaks.weeks.current)
	if maxCurrentStreak > 1999 then 
		fonts.streakValue = Font:getFace("NotoSerif-Regular.ttf", 50)
	elseif maxCurrentStreak > 199 then 
		fonts.streakValue = Font:getFace("NotoSerif-Regular.ttf", 55)	
	end	

	local bestStreakWidget = buildBestStreakWidget(streaks, streaks_dimen, fonts, streaks_colors)	
	local streaks_weekWidget = buildCurrentStreakWidget(streaks_dimen, streaks.weeks.current, 0, fonts, streaks_colors)
	local streaks_dayWidget = buildCurrentStreakWidget(streaks_dimen, streaks.days.current, 1, fonts, streaks_colors)
	local streaksBlock = HorizontalGroup:new{
								streaks_weekWidget, 
								HorizontalSpan:new{ width = Size.padding.large},
								streaks_dayWidget, 
								HorizontalSpan:new{ width = Size.padding.large},
								bestStreakWidget,
	}
	streaksBlock = VerticalGroup:new{
								streaksBlock,
								VerticalSpan:new{ width = Size.padding.large},
	}
	
	-- YEAR DATA BLOCK
    local year_header = buildYearHeader(popup_self, fonts.section, layout, yearRange)	
    local yearly_row = buildYearlyRow(popup_self, yearly_stats, fonts, layout)

    local chart = buildMonthlyChart(popup_self, monthly_data, layout, fonts)
	local yearDataBlock
    if chart and year_header and yearly_row then	
		yearDataBlock = VerticalGroup:new{
						year_header,
						yearly_row,
						chart,
		}
		yearDataBlock = FrameContainer:new{
						padding = 0,
						margin = 0,
						width = streaksBlock:getSize().w,
						height = yearDataBlock:getSize().h,
						color = Blitbuffer.COLOR_GRAY_E,
						bordersize = 0,
						radius = Screen:scaleBySize(7),
						yearDataBlock,
		}
    end		
	table.insert(sections, streaksBlock)	
	table.insert(sections, yearDataBlock)
    return sections
end

Dispatcher:registerAction("reading_insights_popup", {
    category = "none",
    event = "ShowReadingInsightsPopup",
    title = _("Reading statistics: reading insights"),
    general = true,
})

ReadingInsightsPopup = FocusManager:extend{
    modal = true,
    ui = nil,
    width = nil,
    height = nil,
    selected_year = nil, -- for yearly stats section
    mode = nil,
	selected = {x = 1, y = 2}
}

-- Streaks are computed from distinct local dates/weeks in page_stat.
function ReadingInsightsPopup:calculateStreaks()
    local streaks = {
				days = 	{
							current = 0,
							best = 0,
							best_start = 0,
							best_end = 0,							
						},
				weeks = {
							current = 0,
							best = 0,
							best_start = 0,
							best_end = 0,								
						},
    }

    return withStatsDb(streaks, function(conn)
		local dates = {}  
		local sql = [[  
			SELECT date(start_time, 'unixepoch', 'localtime') as d,  
				   min(start_time) as timestamp  
			FROM page_stat   
			GROUP BY d   
			ORDER BY d DESC  
		]]  
		withStatement(conn, sql, function(stmt)  
			for row in stmt:rows() do  
				table.insert(dates, { row[1], tonumber(row[2]) }) -- { date, timestamp}
			end  
		end)

        local today = os.date("%Y-%m-%d")
        local yesterday = os.date("%Y-%m-%d", os.time() - 86400)

        local function isCurrentDayStart(first_date)
            return first_date == today or first_date == yesterday
        end

        local function isConsecutiveDay(prev_date, curr_date)
            local year, month, day = parseDateYMD(prev_date)
            if not year then return false end
            local prev_time = os.time({
                year = year,
                month = month,
                day = day,
            })
            local expected_prev = os.date("%Y-%m-%d", prev_time - 86400)
            return curr_date == expected_prev
        end
				
        streaks.days = computeStreaks(dates, isConsecutiveDay, isCurrentDayStart, 1)

		local weeks = {}
		local sql_weeks = [[  
			SELECT   
				strftime('%G-%V', start_time, 'unixepoch', 'localtime') as week,  
				MIN(start_time) as first_timestamp,  
				MAX(start_time) as last_timestamp  
			FROM page_stat   
			GROUP BY week   
			ORDER BY week DESC  
		]]  
		withStatement(conn, sql_weeks, function(stmt_weeks)  
			for row in stmt_weeks:rows() do  
				table.insert(weeks, {tonumber(row[2]), tonumber(row[3])}) --{first timestamp, last timestamp }
			end  
		end)

        local current_week = os.date("%G-%V")
        local last_week = os.date("%G-%V", os.time() - 7 * 86400)

        local function isCurrentWeekStart(first_week_stamp)
			local first_week = os.date("%G-%V", first_week_stamp)
            return first_week == current_week or first_week == last_week
        end

        local function isConsecutiveWeek(prev_week_stamp, curr_week_stamp)
            local prev_year_wk = parseWeekYear(prev_week_stamp)
            local curr_year_wk = parseWeekYear(curr_week_stamp)
            if not prev_year_wk or not curr_year_wk then
                return false
            end
			
			local expected_curr_year_wk = os.date("%G-%V", prev_week_stamp - (7 * 86400))			
			return curr_year_wk == expected_curr_year_wk
        end

        streaks.weeks = computeStreaks(weeks, isConsecutiveWeek, isCurrentWeekStart, 0)
		
		insightsCache.streaks = streaks
		if streaks then writeInsightsCacheToDisk("streaks") end
        return streaks
    end)
end

function ReadingInsightsPopup:getMonthlyReadingDays(year)
    local months = {}
    return withStatsDb(months, function(conn)
        local year_str = tostring(year)
        local sql = string.format([[
            SELECT strftime('%%Y-%%m', start_time, 'unixepoch', 'localtime') AS month,
                   COUNT(DISTINCT date(start_time, 'unixepoch', 'localtime')) AS days_read
            FROM page_stat
            WHERE strftime('%%Y', start_time, 'unixepoch', 'localtime') = '%s'
            GROUP BY month
            ORDER BY month ASC
        ]], year_str)

        local results = {}
        withStatement(conn, sql, function(stmt)
            for row in stmt:rows() do
                results[row[1]] = row[2]
            end
        end)

        for month_num = 1, 12 do
            local year_month = string.format("%04d-%02d", year, month_num)
            local days = tonumber(results[year_month]) or 0
            table.insert(months, {
                month = year_month,
                days = days,
                label = MONTH_NAMES_SHORT[month_num],
                label_full = MONTH_NAMES_FULL[month_num],
				month_num = month_num
            })
        end
		
		insightsCache.monthlyReadingDays = insightsCache.monthlyReadingDays or {}
		insightsCache.monthlyReadingDays[year] = months
		if months then writeInsightsCacheToDisk("MonthlyReadingDays") end
        return months
    end)
end

function ReadingInsightsPopup:getMonthlyReadingHours(year)
    local months = {}
    return withStatsDb(months, function(conn)
        local year_str = tostring(year)
        local sql = string.format([[
            SELECT dates AS month,
                   SUM(sum_duration) / 3600.0 AS hours_read
            FROM (
                SELECT strftime('%%Y-%%m', start_time, 'unixepoch', 'localtime') AS dates,
                       sum(duration) AS sum_duration
                FROM page_stat
                WHERE strftime('%%Y', start_time, 'unixepoch', 'localtime') = '%s'
                GROUP BY id_book, page, dates
            )
            GROUP BY dates
            ORDER BY dates ASC
        ]], year_str)

        local results = {}
        withStatement(conn, sql, function(stmt)
            for row in stmt:rows() do
                results[row[1]] = row[2]
            end
        end)

        for month_num = 1, 12 do
            local year_month = string.format("%04d-%02d", year, month_num)
            local hours = tonumber(results[year_month]) or 0
            if hours >= 1 then
                hours = math.floor(hours)
            elseif hours > 0 then
                hours = (math.floor(hours * 10)) / 10
            end
            table.insert(months, {
                month = year_month,
                hours = hours,
                label = MONTH_NAMES_SHORT[month_num],
                label_full = MONTH_NAMES_FULL[month_num],
				month_num = month_num
            })
        end
		
		insightsCache.monthlyReadingHours = insightsCache.monthlyReadingHours or {}
		insightsCache.monthlyReadingHours[year] = months
		if months then writeInsightsCacheToDisk("MonthlyReadingHours") end
        return months
    end)
end

function ReadingInsightsPopup:getYearlyStats(year)
    local stats = { days = 0, pages = 0, duration = 0 }
    return withStatsDb(stats, function(conn)
        local year_str = tostring(year)

        local sql_days = string.format([[
            SELECT COUNT(DISTINCT date(start_time, 'unixepoch', 'localtime'))
            FROM page_stat
            WHERE strftime('%%Y', start_time, 'unixepoch', 'localtime') = '%s'
        ]], year_str)
        withStatement(conn, sql_days, function(stmt_days)
            for row in stmt_days:rows() do
                stats.days = tonumber(row[1]) or 0
            end
        end)

        -- Unique (id_book, page) pairs; rereads in the same year do not add to the count.
        local sql_pages = string.format([[
            SELECT count(*)
            FROM (
                SELECT 1
                FROM page_stat
                WHERE strftime('%%Y', start_time, 'unixepoch', 'localtime') = '%s'
                GROUP BY id_book, page
            )
        ]], year_str)
        withStatement(conn, sql_pages, function(stmt_pages)
            for row in stmt_pages:rows() do
                stats.pages = tonumber(row[1]) or 0
            end
        end)

        local sql_duration = string.format([[
            SELECT sum(duration)
            FROM page_stat
            WHERE strftime('%%Y', start_time, 'unixepoch', 'localtime') = '%s'
        ]], year_str)
        withStatement(conn, sql_duration, function(stmt_duration)
            for row in stmt_duration:rows() do
                stats.duration = tonumber(row[1]) or 0
            end
        end)
		
		insightsCache.yearlyStats = insightsCache.yearlyStats or {}
		insightsCache.yearlyStats[year] = stats
		if stats then writeInsightsCacheToDisk("YearlyStats") end
        return stats
    end)
end

function ReadingInsightsPopup:getYearRange()
    local current_year = tonumber(os.date("%Y"))
    local range = { min_year = current_year, max_year = current_year }
    return withStatsDb(range, function(conn)
        local sql = [[
            SELECT MIN(strftime('%Y', start_time, 'unixepoch', 'localtime')) AS min_year,
                   MAX(strftime('%Y', start_time, 'unixepoch', 'localtime')) AS max_year
            FROM page_stat
        ]]
        withStatement(conn, sql, function(stmt)
            for row in stmt:rows() do
                if row[1] then range.min_year = tonumber(row[1]) or current_year end
                if row[2] then range.max_year = tonumber(row[2]) or current_year end
            end
        end)

		insightsCache.yearRange = range
		if range then writeInsightsCacheToDisk("YearRange") end
        return range
    end)
end

local function getBooksForPeriod(period_format, period_value)
    local books = {}
	local pagesTotal = 0
    local result = withStatsDb(books, function(conn)
        -- Count distinct pages per book for the period (ignore rereads of the same page).
        local sql = string.format([[
            SELECT book.title, book.authors, COUNT(DISTINCT page_stat.page) as pages_read
            FROM page_stat
            JOIN book ON page_stat.id_book = book.id
            WHERE strftime('%s', start_time, 'unixepoch', 'localtime') = '%s'
            GROUP BY page_stat.id_book
            ORDER BY pages_read DESC
        ]], period_format, period_value)

        withStatement(conn, sql, function(stmt)
            for row in stmt:rows() do
				local pages_curr = tonumber(row[3]) or 0
                table.insert(books, {
                    title = row[1] or _("Unknown"),
                    authors = row[2] or "",
                    pages = pages_curr,
                })
				pagesTotal = pagesTotal + pages_curr
            end
        end)
        return {books, pagesTotal}
    end)
	return result[1], result[2]
end

-- Get list of books read in a given month (year_month format: "2025-01")
function ReadingInsightsPopup:getBooksForMonth(year_month)
    return getBooksForPeriod("%Y-%m", year_month)
end

local function showBookList(title, books)
    local Menu = require("ui/widget/menu")

    if #books == 0 then
        local InfoMessage = require("ui/widget/infomessage")
        UIManager:show(InfoMessage:new{
            text = _("No books read"),
        })
        return
    end

    local item_table = {}
    for i, book in ipairs(books) do
        local pages_text = N_("page", "pages", book.pages)
        local display_text = book.title
        if book.authors and book.authors ~= "" then
            display_text = display_text .. " (" .. book.authors .. ")"
        end
        table.insert(item_table, {
            text = display_text,
            mandatory = util.getFormattedSize(book.pages) .. " " .. pages_text,
            bold = true,
        })
    end

    local menu
    menu = Menu:new{
        title = title,
        item_table = item_table,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
		modal = true,
        is_borderless = true,
        is_popout = false,
        close_callback = function()
            UIManager:close(menu)
        end,
    }
    UIManager:show(menu)
end

local function showBooksForPeriod(popup_self, books, empty_text, title)
    if #books == 0 then
        local InfoMessage = require("ui/widget/infomessage")
        UIManager:show(InfoMessage:new{
            text = empty_text,
        })
        return
    end

    local ui = popup_self.ui
    local selected_year = popup_self.selected_year
    local mode = popup_self.mode

    showBookList(
        title,
        books,
		pages
    )
end

-- month_label_full should be "January 2025" format
function ReadingInsightsPopup:showBooksForMonth(year_month, month_label_full)
    local books, pages = self:getBooksForMonth(year_month)
	local bookCount = #books
    showBooksForPeriod(
        self,
        books, 
        T(_("No books read in %1"), month_label_full),
        T(("%1 - %2 " .. N_("book", "books", bookCount).." (%3 ".. N_("page", "pages", pages)..")"), month_label_full, bookCount, pages)
    )
end

function ReadingInsightsPopup:getBooksForYear(year)
    return getBooksForPeriod("%Y", tostring(year))
end

function ReadingInsightsPopup:showBooksForYear(year)
    local books, pages = self:getBooksForYear(year)
	local bookCount = #books
    showBooksForPeriod(
        self,
        books,
        _("No books read in ") .. year,
		T(("%1 - %2 " .. N_("book", "books", bookCount).." (%3 ".. N_("page", "pages", pages)..")"), year, bookCount, pages)
    )
end

local function populateEverything(popup_self, year, yearRange)
	logger.info("READING-INSIGHTS-POPUP: POPULATE EVERYTHING CALLED")
	local a = {
		yearRange = yearRange,
		streaks = insightsCache.streaks or popup_self:calculateStreaks(),   
        yearlyStats = insightsCache.yearlyStats and insightsCache.yearlyStats[year] or popup_self:getYearlyStats(year),
        monthlyReadingDays = insightsCache.monthlyReadingDays and insightsCache.monthlyReadingDays[year] or popup_self:getMonthlyReadingDays(year), 
        monthlyReadingHours = insightsCache.monthlyReadingHours and insightsCache.monthlyReadingHours[year] or popup_self:getMonthlyReadingHours(year),
	}	
	return a
end

local function yearExistsInCache(year)
	if insightsCache and insightsCache.yearlyStats and insightsCache.yearlyStats[year] then
		return true
	end
	return false
end

local function getDataToBeDisplayed(popup_self)
	--sets yearRange and selected_year.
	--returns year data if available, else returns fallbackTable.
	
	clearCacheIfRequired()	
    local yearRange = insightsCache.yearRange or popup_self:getYearRange()
    popup_self.yearRange = yearRange
    if not popup_self.selected_year then
        popup_self.selected_year = yearRange.max_year
    end			
	if (not yearExistsInCache(popup_self.selected_year)) or (not insightsCache.streaks) then 
		popup_self.modal = false
		logger.info("READING-INSIGHTS-POPUP: RETURNING FALLBACK ARRAY")
		return fallbackTable		
	end 	
	
	return populateEverything(popup_self, popup_self.selected_year, yearRange)
end

function ReadingInsightsPopup:init()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
	local max_widget_width = screen_w * 5/6	
	if screen_w > screen_h then
		max_widget_width = math.floor(max_widget_width * screen_h / screen_w)
	end	
    self.mode = normalizeInsightsMode(self.mode or readInsightsMode())	
	local everything =  getDataToBeDisplayed(self)	
	local yearRange = self.yearRange
	local streaks = everything.streaks
    local yearly_stats = everything.yearlyStats
    local monthly_data
    if self.mode == INSIGHTS_MODE_HOURS then
        monthly_data = everything.monthlyReadingHours 
    else
        monthly_data = everything.monthlyReadingDays
    end

    local fonts = buildSerifFonts()
    local widget_layout = cachedLayout or buildLayout(max_widget_width, Size.padding.large, Screen:scaleBySize(20))
    local sections = buildInsightsSections(
        self,
        streaks,
        yearly_stats,
        yearRange,
        monthly_data,
        fonts,
        widget_layout, 
		self.selected_year
    )	

    self.popup_frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Screen:scaleBySize(2),
        radius = Screen:scaleBySize(16),
        padding = Screen:scaleBySize(15),
        sections,
    }
		
    self[1] =	
        CenterContainer:new {
        dimen = Screen:getSize(),
        VerticalGroup:new {
            self.popup_frame
        }
    }	
	
    if everything.isPlaceholder then 
		self:onGoToPrevYear(self, self.selected_year) 
    end  

    self.dimen = Geom:new{ w = screen_w, h = screen_h }

    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            }
        }
        self.ges_events.Swipe = {
            GestureRange:new {
                ges = "swipe",
                range = function()
                    return self.dimen
                end
            }	
		}
    end

    if Device:hasKeys() then
		self.key_events.AnyKeyPressed = {{{ "RPgBack", "LPgBack", "RPgFwd", "LPgFwd", "Back", "Home", }}}
    end		
end

function ReadingInsightsPopup:update(popup_self, selected_year, mode)
	popup_self.selected_year = selected_year
	popup_self.mode = mode
	popup_self:free()  
	popup_self:init()  
	UIManager:setDirty(popup_self, "ui", popup_self.dimen)
end

function ReadingInsightsPopup:toggleInsightsMode(popup_self)
    local new_mode = popup_self.mode == INSIGHTS_MODE_HOURS and INSIGHTS_MODE_DAYS or INSIGHTS_MODE_HOURS
    saveInsightsMode(new_mode)
	popup_self:update(popup_self, popup_self.selected_year, new_mode)
	return true
end

local function buildAndShowTargetYear(popup_self, target_year)
	--builds and shows new widget when new year requested.
	--we do it this way because we don't prefer placeholder widgets when moving b/w years.
	
		if (not yearExistsInCache(target_year)) or (not insightsCache.streaks) then 	
			local txt
			if not yearExistsInCache(target_year) then
				txt = "Loading insights for " .. target_year .. "..."
			elseif not insightsCache.streaks then
				txt = "Loading streaks..."
		end
		
		local loading = InfoMessage:new{text = txt}  
		UIManager:show(loading)
		UIManager:tickAfterNext(function() 
									populateEverything(popup_self, target_year, popup_self.yearRange) 
									UIManager:tickAfterNext( function() 
											UIManager:close(loading)
											popup_self:update(popup_self, target_year, popup_self.mode)
									end)
		end)
		return true
	end
	popup_self:update(popup_self, target_year, popup_self.mode)
	

end

function ReadingInsightsPopup:onGoToPrevYear(popup_self, forced_year)
	--pass forced_year arg. to repurpose this function to 
	--change years using year selector.
	
	local target_year = nil
	if forced_year then 
        target_year = forced_year
	end
    if not forced_year then 
		if self.selected_year > self.yearRange.min_year then
        target_year = self.selected_year - 1
		end
	end
	if not target_year then return end
	buildAndShowTargetYear(popup_self, target_year)
end

function ReadingInsightsPopup:onGoToNextYear(popup_self)
	local target_year = nil
    if self.selected_year < self.yearRange.max_year then
        target_year = self.selected_year + 1
    end
	if not target_year then return end
	buildAndShowTargetYear(popup_self, target_year)
end

function ReadingInsightsPopup:onAnyKeyPressed(_, key)
    if key and key:match({ { "RPgBack", "LPgBack" } }) then
        return self:onGoToPrevYear(self)
    end
    if key and key:match({ { "RPgFwd", "LPgFwd"} }) then
        return self:onGoToNextYear(self)
    end
    UIManager:close(self)
    return true
end

function ReadingInsightsPopup:onSwipe(arg, ges_ev)
	if ges_ev.direction == "east" then
        return self:onGoToPrevYear(self)
    elseif ges_ev.direction == "west" then
        return self:onGoToNextYear(self)
    else
		UIManager:close(self)
		return true
	end
end

function ReadingInsightsPopup:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.popup_frame.dimen
    end)
    return true
end


function ReadingInsightsPopup:onTapClose(arg, ges)
    if ges.pos:notIntersectWith(self.popup_frame.dimen) then  
		UIManager:close(self)
	end
    return true
end

function ReadingInsightsPopup:onCloseWidget()
	G_reader_settings:delSetting("readingInsights_cache")
	G_reader_settings:delSetting("readingInsights_cacheTimestamps")
    UIManager:setDirty(nil, "ui")
end

-- Hook into ReaderUI to handle the event
function ReaderUI.onShowReadingInsightsPopup(this)
    local popup = ReadingInsightsPopup:new{
        ui = this,
    }
    UIManager:show(popup)
    return true
end

function FileManager:onShowReadingInsightsPopup()
    local popup = ReadingInsightsPopup:new{
        ui = this,
    }
    UIManager:show(popup)
    return true
end

-- Patch stats plugin to record last sync timestamp
local userpatch = require("userpatch")

local function saveLastSyncTimestamp(plugin)	
	local original_plugin_onSyncBookStats = plugin.onSyncBookStats
	
	function plugin:onSyncBookStats()
		local now = os.time()
		cache_timestamps.statsSynced = now
		writeCacheTimestampsToDisk()		
		return original_plugin_onSyncBookStats(self)		
	end
       
end
userpatch.registerPatchPluginFunc("statistics", saveLastSyncTimestamp)
