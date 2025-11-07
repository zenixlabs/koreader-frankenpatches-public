--[[

i found that chapter ticks on a regular progress bar wasn't for me. i wanted a 
separate progress bar for chapter that also didn't clutter up the ui. so i made this.

this patch joins two half-sized progress bars end to end 
to make them look like one regular progress bar.

you can choose what progress (chapter/book) to show on either side and there's
also an option to 'mirror' the progress bars. for eg., chapter progress on both sides
plus mirrored = ON and gap = 0 will essentially give you one regular size progress bar 
that fills from the centre towards the edges.  

you should probably disable the default koreader progress bar and definitely 
uncheck 'auto refresh items' from status bar settings for this to work properly.

this patch works really well on my kindle 4 and kindle basic 2019.

you'll find instructions to configure this patch if you scroll down.

happy reading! =)

CREDITS: some outline code for this was borrowed from a user patch made by 
joshua cantara. (https://github.com/joshuacant/KOReader.patches)

]]--

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Size = require("ui/size")
local Screen = Device.screen
local ReaderView = require("apps/reader/modules/readerview")
local _ReaderView_paintTo_orig = ReaderView.paintTo
local screen_width = Screen:getWidth()
local screen_height = Screen:getHeight()
local ProgressWidget = require("ui/widget/progresswidget")
local UIManager = require("ui/uimanager")

ReaderView.paintTo = function(self, bb, x, y)
    _ReaderView_paintTo_orig(self, bb, x, y)
    if self.render_mode ~= nil then return end -- Show only for epub-likes and never on pdf-likes

--  book info
local pageno = self.state.page or 1 -- Current page
local pages = self.ui.doc_settings.data.doc_pages or 1
local pages_left_book  = pages - pageno
-- chapter info
local pages_chapter = self.ui.toc:getChapterPageCount(pageno) or pages
local pages_left = self.ui.toc:getChapterPagesLeft(pageno) or self.ui.document:getTotalPagesLeft(pageno)
local pages_done = self.ui.toc:getChapterPagesDone(pageno) or 0
pages_done = pages_done + 1 -- This +1 is to include the page you're looking at.
local BOOK_MARGIN = self.document:getPageMargins().left
local CHAPTER = 0
local BOOK = 1
local ON = true
local OFF = false 



-------------------------------------------------------
-- adjust the values below to configure progress bars.
-------------------------------------------------------

local prog_bar_height = 2 -- progress bar height.
local bottom_padding = 35 -- space b/w progress bars and bottom edge.
local margin = BOOK_MARGIN -- use BOOK_MARGIN or any numeric value.
local gap = 0 -- gap between progress bars.
local radius = 0 -- make the ends a little round.
local mirrored = ON -- mirrored progress bars ON or OFF.
local left_bar_type = CHAPTER -- set this to CHAPTER or BOOK
local right_bar_type = CHAPTER -- set this to CHAPTER or BOOK

------------------------------------------------------
-- you don't have to change anything below this line.
------------------------------------------------------



screen_width = Screen:getWidth()
screen_height = Screen:getHeight()

local chapter_percentage = pages_done/pages_chapter
local inv_chapter_percentage = pages_left/pages_chapter
local book_percentage = pageno/pages
local inv_book_percentage = pages_left_book/pages

local left_bar_percentage
local left_bar_inv_percentage
local left_bar_fill_color
local left_bar_bg_color
local right_bar_percentage

local pblack = Blitbuffer.COLOR_GRAY_4
local pgray = Blitbuffer.COLOR_GRAY

local prog_bar_width =  (screen_width - gap - margin*2) / 2
local prog_bar_y = screen_height - prog_bar_height - bottom_padding

-- left bar

if left_bar_type == 0 then
    left_bar_percentage = chapter_percentage
    left_bar_inv_percentage = inv_chapter_percentage
else
    left_bar_percentage = book_percentage
    left_bar_inv_percentage = inv_book_percentage
end

if mirrored then
    left_bar_percentage = left_bar_inv_percentage
    left_bar_fill_color = pgray
    left_bar_bg_color = pblack
else
    left_bar_fill_color = pblack
    left_bar_bg_color = pgray
end

local left_bar = ProgressWidget:new{
    width = prog_bar_width,
    height = prog_bar_height,
    percentage = left_bar_percentage,
    margin_v = 0,
    margin_h = 0,
    radius = radius,
    bordersize = 0,
    fillcolor = left_bar_fill_color,
    bgcolor = left_bar_bg_color,
}

-- right bar

if right_bar_type == 0 then
    right_bar_percentage = chapter_percentage
else
    right_bar_percentage = book_percentage
end

local right_bar = ProgressWidget:new{
    width = prog_bar_width,
    height = prog_bar_height,
    percentage = right_bar_percentage,
    margin_v = 0,
    margin_h = 0,
    radius = radius,
    bordersize = 0,
    fillcolor = pblack,
    bgcolor = pgray,
}
local right_bar_x = Screen:getWidth()/ 2 + gap / 2

left_bar:paintTo(bb, margin, prog_bar_y)
right_bar:paintTo(bb, right_bar_x, prog_bar_y)

end
