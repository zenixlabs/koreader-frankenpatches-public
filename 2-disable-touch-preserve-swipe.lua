--[ disable-touch-preserve-swipe v1.0.2 ]

-- WHAT DOES THIS PATCH DO?
-- disables all touch inputs EXCEPT page-turn swipes.

-- SETUP:
-- copy the .lua file to koreader/patches directory and restart koreader.
-- assign any gesture to the 'Toggle touch input' action under 'Device' category.
-- that's it. you can use that gesture to disable and re-enable touch inputs.

-- TROUBLESHOOTING:
-- in case you get locked out, put the device to sleep and wake it back up.

local userpatch = require("userpatch")

local function preserve_swipe_toggleTouchInput(plugin)	
	local Gestures = plugin
	local orig_isGestureAlwaysActive = Gestures.isGestureAlwaysActive
	
	function Gestures:isGestureAlwaysActive(ges, multiswipe_directions)
		if ges == "swipe" or ges == "pan_swipe" or ges == "paging_swipe" or ges == "rolling_swipe" then 
			return true 
		end			
		return orig_isGestureAlwaysActive(self, ges, multiswipe_directions)
	end    
end
userpatch.registerPatchPluginFunc("gestures", preserve_swipe_toggleTouchInput)
