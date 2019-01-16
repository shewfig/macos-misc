-- mouse buttons (minus 1 from standard numbering)
-- Format:
-- -- DeviceID (0 for all mice)
-- -- -- scollSpeed = [ 0 - 3 ]
-- -- -- [button number]
-- -- -- -- onDrag
-- -- -- -- onClick
mouseOverrides = {
	[0] = {
		-- default settings
		trackSpeed = 1.5,
	},
	[1133] = {
		-- Logitech
		[50184] = {
			-- TrackMan Marble
			trackSpeed = 3,
			[3] = {
				onDrag = function (e) return doScroll(-4, e) end,
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
	}
}

--
-- Dereference abstractions into functions
--

-- Mouse button events:
-- otherMouseDragged       27
-- otherMouseDown          25
-- otherMouseUp            26
print("Parsing configuration")
for vendID,devSet in pairs(mouseOverrides) do
	print("Vendor: "..vendID)
	if type(vendID) == 'number' then
		for k,v in pairs(devSet) do
			if type(k) == 'number' then
				print("Device: "..k)
				for mb,_ in pairs(v) do
					if type(mb) == 'number' then
						if nil ~= mouseOverrides[vendID][k][mb]["onClick"] then
							print("Expanding onClick: "..mb)
							mouseOverrides[vendID][k][mb][25] = function (e) return mHandleDown(e) end
							mouseOverrides[vendID][k][mb][26] = function (e) return mHandleUp(e) end
						end
						if nil ~= mouseOverrides[vendID][k][mb]["onDrag"] then
							print("Expanding onDrag: "..mb)
							mouseOverrides[vendID][k][mb]["dNum"] = 0
							mouseOverrides[vendID][k][mb][27] = function (e) return mouseOverrides[vendID][k][mb]["onDrag"](e) end
						end
					end
				end
			end
		end
	end
end

-- coding shortcuts
local eet = hs.eventtap.event.types
local eep = hs.eventtap.event.properties

-- Actions
function doScroll(scrollmult, e)
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
	mouseSet[e:getProperty(eep.mouseEventButtonNumber)].dNum = -1
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
	mouseSet[mBNum].dNum = e:getProperty(eep.mouseEventNumber)
	--print ("mouseDown: " .. mBNum .. "." .. mouseSet[mBNum].dNum)

	if 0 == mouseSet[mBNum].dNum then
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
	--print ("mouseUp: " .. mBNum .. "." .. mouseUNum .. ", down state: " .. mouseSet[mBNum].dNum)
	if 0 == mouseSet[mBNum].dNum and 0 == mouseUNum then
		-- faked click, let it pass
		--print("Synthetic click"..mBNum)
		return false
	elseif -1 == mouseSet[mBNum].dNum then
		-- scrolled, drop it
		--print("Suppressed"..mBNum)
		return true
	elseif mouseUNum == mouseSet[mBNum].dNum then
		if nil ~= mouseSet[mBNum]["onClick"] then
			--print("onClick: "..mBNum)
			rv = mouseSet[mBNum].onClick(e)
			--print("Clickaction:"..tostring(rv))
			if nil ~= rv then
				return rv
			else
				-- default: suppress
				return true
			end
		else
			--mouseSet[mBNum].dNum = 0
			-- real click, create a fake one
			--print ("CLICK!")
			--print("otherClick: "..mBNum)
			hs.eventtap.otherClick(hs.mouse.getAbsolutePosition(), nil, mBNum)
			return true
		end
	else
		--print("What?!".."mouseUp: " .. mBNum .. "." .. mouseUNum .. ", down state: " .. mouseSet[mBNum].dNum)
		return false
	end
end

-- mouseSet as global
mouseSet = nil
function eventDispatch(e)
	--print("mouseSet["..e:getProperty(eep.mouseEventButtonNumber).."]["..e:getType().."](e)")
	-- No real need to check: if error, false gets returned, which lets the event through
	if nil ~= mouseSet[e:getProperty(eep.mouseEventButtonNumber)] then
		cb = mouseSet[e:getProperty(eep.mouseEventButtonNumber)][e:getType()]
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

-- Register actions

-- define mouseTrap as a global
mouseTrap = nil
function mouseSettingsApply(devSet)
	-- set event triggers for defined events per mouse button
	-- evl is the list of event types to trap
	local evl = {}
	local flags = {}
	for mb, evt in pairs(devSet) do
		if type(evt) == 'table' then
			print("Button: "..mb)
			for tev, val in pairs(evt) do
				if type(tev) == 'number' then
					if (not flags[tev]) then
						evl[#evl+1] = tev
						flags[tev] = true
						print("Event: "..tev)
					end
				else
					if type(val) == 'number' or type(val) == 'string' then
						print(tev.."="..val)
					else
						print(tev.."="..type(val))
					end
				end
			end
		else
			hs.inspect(evt)
		end
	end
	if nil ~= devSet['trackSpeed'] then
		hs.mouse.trackingSpeed(devSet['trackSpeed'])
		print("Tracking speed: "..hs.mouse.trackingSpeed())
	end
	if #evl > 0 then
		-- for k,v in pairs(evl) do --print(v) end
		mouseTrap = hs.eventtap.new(evl, eventDispatch)
		mouseTrap:start()
		return true
	end
	return false
end

function findMouse(devList)
	for venID, vDevs in pairs(mouseOverrides) do
		if 0 ~= venID then
			for devID,_ in pairs(vDevs) do
				for _,uDev in pairs(devList) do
					if uDev.vendorID == venID and uDev.productID == devID then
						print("Found mouse: "..venID..":"..devID)
						return venID, devID
					end
				end
			end
		end
	end
	return false
end

function usbWatcherHandler (e)
	if e.eventType == 'removed' then
		print("Device removed: "..e.vendorID.."."..e.productID)
		if nil ~= mouseOverrides[e.vendorID] and nil ~= mouseOverrides[e.vendorID][e.productID] then
			hs.mouse.trackingSpeed(mouseOverrides[0]['trackSpeed'])
			print("Tracking speed: "..hs.mouse.trackingSpeed())
			mouseTrap:stop()
		end
	elseif e.eventType == 'added' then
		print("Device added: "..e.vendorID.."."..e.productID)
		if nil ~= mouseOverrides[e.vendorID] and nil ~= mouseOverrides[e.vendorID][e.productID] then
			if true == mouseSettingsApply(mouseOverrides[e.vendorID][e.productID]) then
				mouseSet = mouseOverrides[e.vendorID][e.productID]
				if nil ~= mouseSet['trackSpeed'] then
					hs.mouse.trackingSpeed(mouseSet['trackSpeed'])
					print("Tracking speed: "..hs.mouse.trackingSpeed())
				end
			end
		end
	end
end

mouseCount = 0
for _,_ in pairs(mouseOverrides) do
	mouseCount = mouseCount + 1
end
if mouseCount > 1 then
	mouseVID, mouseDID = findMouse(hs.usb.attachedDevices())
	if nil ~= mouseOverrides[mouseVID] and nil ~= mouseOverrides[mouseVID][mouseDID] then
		print("Settings found, validating")
		if true == mouseSettingsApply(mouseOverrides[mouseVID][mouseDID]) then
			print("Applying")
			mouseSet = mouseOverrides[mouseVID][mouseDID]
		else
			print("Failed!")
		end
	else
		print("Unknown device")
	end
	mouseWatcher = hs.usb.watcher.new(usbWatcherHandler)
	mouseWatcher:start()
end
