-- HANDLE SCROLLING
local oldmousepos = {}
-- positive multiplier (== natural scrolling) makes mouse work like traditional scrollwheel
local scrollmult = -4 

local eet = hs.eventtap.event.types
local eep = hs.eventtap.event.properties

-- The were all events logged, when using `{"all"}`
mouseevent = hs.eventtap.new({eet.otherMouseDragged}, function(e)
	local eventType = eet[e:getType()]
	local buttonPressed = e:getProperty(eep.mouseEventButtonNumber)
	local buttonClickType = e:getProperty(eep.mouseEventClickState) ~= 0 and e:getProperty(eep.mouseEventClickState) or 0

	-- If OSX button 4 is pressed, allow scrolling
	local shouldScroll = 2 == buttonPressed
	if shouldScroll then
		oldmousepos = hs.mouse.getAbsolutePosition()
		local dx = e:getProperty(hs.eventtap.event.properties['mouseEventDeltaX'])
		local dy = e:getProperty(hs.eventtap.event.properties['mouseEventDeltaY'])
		local scroll = hs.eventtap.event.newScrollEvent({dx * scrollmult, dy * scrollmult},{},'pixel')
		scroll:post()

		-- put the mouse back
		hs.mouse.setAbsolutePosition(oldmousepos)

		return true, {scroll}
	else
		return false, {}
	end
	-- print ("Mouse moved!")
	-- print (dx)
	-- print (dy)
end)
mouseevent:start()
