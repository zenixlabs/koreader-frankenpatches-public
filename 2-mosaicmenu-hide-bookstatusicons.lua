-- hides book status indicators that appear at the lower right corners of thumbnails in mosaicmenu

local userpatch = require("userpatch")

local function removeBookProgressIndicator(plugin)
	-- logic: force 'self.do_hint_opened' to 'false' just before the paintTo() runs
	-- and set it back afterwards.
	
	local MosaicMenu = require("mosaicmenu")
	local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    
    local original_MosaicMenuItem_paintTo = MosaicMenuItem.paintTo    
    function MosaicMenuItem:paintTo(bb, x, y)	
		local orig_self_do_hint_opened = self.do_hint_opened
		self.do_hint_opened = false
        original_MosaicMenuItem_paintTo(self, bb, x, y)
		self.do_hint_opened = orig_self_do_hint_opened
		return true
	end       
end
userpatch.registerPatchPluginFunc("coverbrowser", removeBookProgressIndicator)