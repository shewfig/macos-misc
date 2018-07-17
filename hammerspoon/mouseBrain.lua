-- positive multiplier (== natural scrolling) makes mouse work like traditional scrollwheel
local scrollmult = -4

-- tracking speed numbers
tsSettings = {
	[0] = 1.5,
	[50184] = 3
}

-- mouse buttons (minus 1 from standard numbering)
-- Supported abstractions:
-- -- onDrag
-- -- onClick
mBs = {
	[3] = {
		onDrag = function (e) return doScroll(e) end,
		onClick = function () 
			hs.eventtap.otherClick(hs.mouse.getAbsolutePosition(), 400, 2) 
			return true
		end
	},
	[4] = { 
		onClick = function () 
			hs.eventtap.keyStroke({'ctrl'}, 'up', 400) 
			return true
		end
	}
}

-- Mouse button events:
-- otherMouseDragged       27
-- otherMouseDown          25
-- otherMouseUp            26
for k,v in pairs(mBs) do
	mBs[k]["dNum"] = 0
	if mBs[k]["onClick"] ~= nil then
		mBs[k][25] = function (e) return mHandleDown(e) end
		mBs[k][26] = function (e) return mHandleUp(e) end
	end
	if mBs[k]["onDrag"] ~= nil then
		mBs[k][27] = function (e) return mBs[k]["onDrag"](e) end
	else
		mBs[k][27] = function (e) return killMouseDown(e) end
	end
end

-- coding shortcuts
local eet = hs.eventtap.event.types
local eep = hs.eventtap.event.properties

-- Actions
function doScroll(e)
	--print "doScroll"
	-- signal mouseUp not to fire
	killMouseDown(e)
	-- measure the scroll
	local oldmousepos = hs.mouse.getAbsolutePosition()
	local dx = e:getProperty(hs.eventtap.event.properties['mouseEventDeltaX'])
	local dy = e:getProperty(hs.eventtap.event.properties['mouseEventDeltaY'])
	-- scroll
	hs.eventtap.event.newScrollEvent({dx * scrollmult, dy * scrollmult},{},'pixel'):post()
	-- put the mouse back
	hs.mouse.setAbsolutePosition(oldmousepos)
	-- suppress real event
	return true
end

function killMouseDown(e)
	-- kill the mouse click
	mBs[e:getProperty(eep.mouseEventButtonNumber)].dNum = -1
	-- do nothing else interesting
	return false
end

tKeyHold = false
function doKeyMap(e)
	if tKeyHold then
		--print("doKeyMap: deferred")
		return false
	else
		-- local oldmousepos = hs.mouse.getAbsolutePosition()
		local dx = e:getProperty(hs.eventtap.event.properties['mouseEventDeltaX'])
		local dy = e:getProperty(hs.eventtap.event.properties['mouseEventDeltaY'])
		if math.abs(dx) > math.abs(dy) then
			if dx > 0 then
				arrowKeyDir = 'right'
			else
				arrowKeyDir = 'left'
			end
		else
			if dy > 0 then
				arrowKeyDir = 'down'
			else
				arrowKeyDir = 'up'
			end
		end
		--print("doKeyMap:"..arrowKeyDir)
		-- hs.mouse.setAbsolutePosition(oldmousepos)
		-- hs.eventtap.event.newKeyEvent({'ctrl'}, arrowKeyDir, true):post()
		-- hs.eventtap.event.newKeyEvent({'ctrl'}, arrowKeyDir, false):post()
		hs.eventtap.keyStroke({'ctrl'}, arrowKeyDir)
		tKeyHold = true
		hs.timer.doAfter(1, function () tKeyHold=false end)
		return true
	end
end

function mHandleDown(e)
	--print "HandleDown"
	local mBNum = e:getProperty(eep.mouseEventButtonNumber)
	mBs[mBNum].dNum = e:getProperty(eep.mouseEventNumber)
	--print ("mouseDown: " .. mBNum .. "." .. mBs[mBNum].dNum)

	if 0 == mBs[mBNum].dNum then
		-- faked click, let it pass
		return false
	else
		-- real click, drop it (for now)
		return true
	end
end

function mHandleUp(e)
	--print "mHandleUp"
	local mBNum = e:getProperty(eep.mouseEventButtonNumber)
	local mouseUNum = e:getProperty(eep.mouseEventNumber)
	--print ("mouseUp: " .. mBNum .. "." .. mouseUNum .. ", down state: " .. mBs[mBNum].dNum)
	if 0 == mBs[mBNum].dNum and 0 == mouseUNum then
		-- faked click, let it pass
		--print("Synthetic click"..mBNum)
		return false
	elseif -1 == mBs[mBNum].dNum then
		-- scrolled, drop it
		--print("Suppressed"..mBNum)
		return true
	elseif mouseUNum == mBs[mBNum].dNum then
		if nil ~= mBs[mBNum]["onClick"] then
			--print("onClick: "..mBNum)
			rv = mBs[mBNum].onClick(e)
			--print("Clickaction:"..tostring(rv))
			if nil ~= rv then
				return rv
			else
				-- default: suppress
				return true
			end
		else
			--mBs[mBNum].dNum = 0
			-- real click, create a fake one
			--print ("CLICK!")
			--print("otherClick: "..mBNum)
			hs.eventtap.otherClick(hs.mouse.getAbsolutePosition(), nil, mBNum)
			return true
		end
	else
		--print("What?!".."mouseUp: " .. mBNum .. "." .. mouseUNum .. ", down state: " .. mBs[mBNum].dNum)
		return false
	end
end

function eventDispatch(e)
	--print("mBs["..e:getProperty(eep.mouseEventButtonNumber).."]["..e:getType().."](e)")
	-- No real need to check: if error, false gets returned, which lets the event through
	if nil ~= mBs[e:getProperty(eep.mouseEventButtonNumber)] then
		cb = mBs[e:getProperty(eep.mouseEventButtonNumber)][e:getType()]
		--print("CB:"..tostring(cb))
		if nil ~= cb then
			local retval = cb(e)
			--print("RV(top):"..tostring(retval))
			return retval
		else
			return false
		end
	end
end

-- set event triggers for defined events per mouse button
local evl = {}
local flags = {}
for mb, evt in pairs(mBs) do
	if type(mb) == 'number' then
		for tev, val in pairs(evt) do
			if type(tev) == 'number' then
				if (not flags[tev]) then
					evl[#evl+1] = tev
					flags[tev] = true
					--print("Registering event: "..tev)
				end
			end
		end
	end
end
if #evl > 0 then
	-- for k,v in pairs(evl) do --print(v) end
	mouseTrap = hs.eventtap.new(evl, eventDispatch)
	mouseTrap:start()
end

function usbWatcherHandler (e)
	if e.eventType == 'removed' then
		hs.mouse.trackingSpeed(tsSettings[0])
		--print(hs.mouse.trackingSpeed())
	elseif e.eventType == 'added' then
		if nil ~= tsSettings[e.productID] then
			hs.mouse.trackingSpeed(tsSettings[e.productID])
			--print(hs.mouse.trackingSpeed())
		end
	end
end

tsCount = 0
for _,_ in pairs(tsSettings) do
	tsCount = tsCount + 1
end
if tsCount > 1 then
	mouseWatcher = hs.usb.watcher.new(usbWatcherHandler)
	mouseWatcher:start()
end
