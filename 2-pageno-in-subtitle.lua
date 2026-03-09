--[[ 2-pageno-in-subtitle.lua ]]
--appends 'page x of y' to filemanager subtitle

--[ v1.1.4 ]
--added: pathchooser support

local BD = require("ui/bidi")
local FileManager = require("apps/filemanager/filemanager")
local FileManagerCollection = require("apps/filemanager/filemanagercollection") 
local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local Menu = require("ui/widget/menu")
local PathChooser = require("ui/widget/pathchooser")  
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

--FILE MANAGER

local og_fm_updatePath = FileManager.updateTitleBarPath

function FileManager:updateTitleBarPath(path)
	local path = self.file_chooser.path or path or filemanagerutil.getDefaultDir()
	local text = BD.directory(filemanagerutil.abbreviate(path))
	local fc = self.file_chooser  
	local current_page = fc.page  
	local total_pages = fc.page_num  	
	
	local dir_name = util.splitToArray(text, "/")
	dir_name = dir_name[#dir_name]
	text = total_pages ~= 0 and 
			dir_name .." - "..T(_("Page %1 of %2"), current_page, total_pages) or
			dir_name
    if self.folder_shortcuts:hasFolderShortcut(path) then
        text = "☆ " .. text
    end
    self.title_bar:setSubTitle(text)	
end

local og_fm_setupLayout = FileManager.setupLayout

function FileManager:setupLayout()
	og_fm_setupLayout(self)
	
	--update when going to diff page
    function self.file_chooser:onGotoPage(page)  
        Menu.onGotoPage(self, page)  
        if self.name == "filemanager" then  
            self.ui:updateTitleBarPath(self.path)  
        end  
        return true  
    end  
	
	--update when display mode is changed
    local og_switchItemTable = self.file_chooser.switchItemTable 
    function self.file_chooser:switchItemTable(title, item_table, select_number, itemmatch, subtitle)  
        og_switchItemTable(self, title, item_table, select_number, itemmatch, subtitle)  
        if self.name == "filemanager" then  
            self.ui:updateTitleBarPath(self.path)  
        end  
    end  

end

local og_fm_onPathCh = FileManager.onPathChanged

function FileManager:onPathChanged(path)
	if og_fm_onPathCh then 
		og_fm_onPathCh(self, path)
	end
	self:updateTitleBarPath(self.file_chooser.path or path or filemanagerutil.getDefaultDir())	
	
end

-- PATH CHOOSER  

local og_pc_init = PathChooser.init  

function pc_setSubtitle(pc_self)
	local path = pc_self.path or ""
	if pc_self.title_bar then  
		local page_info = pc_self.page_num ~= 0 and   
						path.." ("..T(_("pg %1/%2"), pc_self.page, pc_self.page_num)..")" or ""  
		pc_self.title_bar:setSubTitle(page_info, true)  
	end  
end
  
function PathChooser:init()  
    og_pc_init(self)  
      
    --update when page changed.
    local og_onGotoPage = self.onGotoPage  
    function self:onGotoPage(page)  
        og_onGotoPage(self, page)  
		pc_setSubtitle(self) 
        return true  
    end  
      
    --whn new dir
    local og_switchItemTable = self.switchItemTable  
    function self:switchItemTable(title, item_table, select_number, itemmatch, subtitle)  
        og_switchItemTable(self, title, item_table, select_number, itemmatch, subtitle) 
		pc_setSubtitle(self)
    end  
      
    --refresh for first page 
    if self.title_bar then  
		pc_setSubtitle(self) 
    end  
end

--=== MASTER FUNC (for coll. and history) ===--

local function addPageNos(item_self, item_name)
    if item_self.booklist_menu then    
        local og_updatePageInfo = item_self.booklist_menu.updatePageInfo    
        function item_self.booklist_menu:updatePageInfo(select_number)    
            og_updatePageInfo(self, select_number)    
            if self.name == item_name and self.title_bar then    
                local page_info = self.page_num ~= 0 and 
									T(_("Page %1 of %2"), self.page, self.page_num) or ""	
                self.title_bar:setSubTitle(page_info, true)    
            end    
        end    
		
        --update subtitle immediately for the first page            
        if item_self.booklist_menu.title_bar then  
            local page_info = item_self.booklist_menu.page_num ~= 0 and
							T(_("Page %1 of %2"), item_self.booklist_menu.page, item_self.booklist_menu.page_num) or ""   
            item_self.booklist_menu.title_bar:setSubTitle(page_info, true)  
        end  
    end  
end	

--HISTORY 

local og_onShowHist = FileManagerHistory.onShowHist  
  
function FileManagerHistory:onShowHist(search_info)     
    local a = og_onShowHist(self, search_info)    
    addPageNos(self, "history")
    return a  
end

--COLLECTION
 
local og_onShowColl = FileManagerCollection.onShowColl  
  
function FileManagerCollection:onShowColl(collection_name)  
    local a = og_onShowColl(self, collection_name)      
	addPageNos(self, "collections")	
    return a  
end