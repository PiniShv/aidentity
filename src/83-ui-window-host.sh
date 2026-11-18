# ------------------------------------------------------------- ui: window host --
#
# The program osascript runs for `aidentity ui --window`: AppleScript that uses
# AppKit and WebKit, given on its stdin. Its arguments are the bash to run and
# the path of this script. It draws one window with a web view, shows the page
# from `aidentity __window page`, and passes each request of the page to one
# `aidentity __window …` command (see 82-ui-window.sh). It takes no decision
# of its own.
#
#   page  --a message (WebKit's script message handler)-->  host
#   host  --runs aidentity __window state|do …, reads its output-->
#   host  --a call of the page's aidReply, the answer as an argument-->  page
#
# The page can ask for two things only, "state" and "do", each with a short
# list of plain words. The words are handed to aidentity as separate
# arguments, never through a shell, and aidentity checks every one of them.
# Text goes back to the page as an argument of a call, never inside script
# text. The web view does not keep the page's data (macOS still keeps WebKit's
# own housekeeping files for osascript; the guide names them), takes no
# dropped file or link, and shows the page again if anything else is ever
# loaded in it.
#
# A command that is running when the window is closed is never cut off: the
# window goes, and this program ends once the command has finished.
#
# Two more arguments are for the test suite: a third one keeps the window off
# the screen, and a fourth names a script to run in the page. Only then does
# the host take a third request, "report", which prints one line and closes
# the window, or quits. `aidentity ui --window` never passes either.
uiw_host_script() {
  cat <<'OSA'
use framework "Foundation"
use framework "AppKit"
use framework "WebKit"
use scripting additions

property shellPath : ""
property cliPath : ""
property testing : false
property driven : false
property theWindow : missing value
property theWeb : missing value
property pageSource : missing value
property theTask : missing value
property taskKind : ""
property taskId : missing value
property sentIcons : missing value
property started : false
property closing : false
property expected : false
property failure : ""
property zoomLevel : 1.0

on run argv
	if (count of argv) < 2 then error "The window was started without its two arguments."
	set my shellPath to item 1 of argv
	set my cliPath to item 2 of argv
	set driver to missing value
	if (count of argv) > 2 then set my testing to true
	if (count of argv) > 3 then
		set driver to current application's NSString's stringWithContentsOfFile:(item 4 of argv) encoding:4 |error|:(missing value)
		if driver is missing value then error "The test script could not be read."
		set my driven to true
	end if
	set my pageSource to my readPage()

	set theApp to current application's NSApplication's sharedApplication()
	if my testing then
		theApp's setActivationPolicy:2
	else
		theApp's setActivationPolicy:0
	end if
	-- Ask for the name aidentity in the menu bar. The Dock and the app switcher
	-- show osascript all the same: they take the name of the program file.
	current application's NSProcessInfo's processInfo()'s setProcessName:"aidentity"
	theApp's setDelegate:me
	theApp's setMainMenu:(my menuBar())

	set cfg to current application's WKWebViewConfiguration's alloc()'s init()
	-- Let Tab stop at every button and field. Otherwise it follows macOS's
	-- Keyboard navigation setting, off at first: text fields and lists only.
	cfg's |preferences|()'s setTabFocusesLinks:true
	cfg's setWebsiteDataStore:(current application's WKWebsiteDataStore's nonPersistentDataStore())
	cfg's userContentController()'s addScriptMessageHandler:me |name|:"aid"
	if my driven then
		cfg's userContentController()'s addUserScript:(current application's WKUserScript's alloc()'s initWithSource:driver injectionTime:1 forMainFrameOnly:true)
	end if
	set frame to current application's NSMakeRect(0, 0, 980, 680)
	set my theWeb to current application's WKWebView's alloc()'s initWithFrame:frame configuration:cfg
	my theWeb's setNavigationDelegate:me
	my theWeb's unregisterDraggedTypes()
	set my theWindow to current application's NSWindow's alloc()'s initWithContentRect:frame styleMask:15 backing:2 defer:false
	my theWindow's setTitle:"aidentity"
	my theWindow's setReleasedWhenClosed:false
	my theWindow's setContentMinSize:(current application's NSMakeSize(560, 420))
	my theWindow's setContentView:(my theWeb)
	my theWindow's |center|()
	my theWindow's setDelegate:me
	my showPage()
	if not (my testing) then
		-- In front of the terminal it was started from, with the keyboard. A
		-- program may only ask macOS for that, and how it asks differs by version.
		my theWindow's makeKeyAndOrderFront:me
		my theWindow's orderFrontRegardless()
		if (theApp's respondsToSelector:"activateIgnoringOtherApps:") as boolean then theApp's activateIgnoringOtherApps:true
		if (theApp's respondsToSelector:"activate") as boolean then theApp's |activate|()
	end if
	-- A page that never asks for anything did not start: say so and end.
	current application's NSTimer's scheduledTimerWithTimeInterval:30 target:me selector:"startCheck:" userInfo:(missing value) repeats:false
	theApp's |run|()
	set why to (my failure) as text
	if why is not "" then error why
end run

-- The page, from aidentity itself, with a fresh key for its content policy.
on readPage()
	set t to current application's NSTask's alloc()'s init()
	t's setLaunchPath:(my shellPath)
	t's setArguments:{my cliPath, "__window", "page"}
	set p to current application's NSPipe's pipe()
	t's setStandardOutput:p
	t's setStandardInput:(current application's NSFileHandle's fileHandleWithNullDevice())
	t's |launch|()
	set d to p's fileHandleForReading()'s readDataToEndOfFile()
	t's waitUntilExit()
	set s to current application's NSString's alloc()'s initWithData:d encoding:4
	if s is missing value then error "The window's page could not be read."
	if ((t's terminationStatus()) as integer) is not 0 or ((s's |length|()) as integer) < 100 then error "The window's page could not be read."
	set k to (current application's NSUUID's UUID()'s UUIDString())'s stringByReplacingOccurrencesOfString:"-" withString:""
	return s's stringByReplacingOccurrencesOfString:"__AIDENTITY_NONCE__" withString:k
end readPage

on showPage()
	set my sentIcons to current application's NSMutableSet's |set|()
	set my expected to true
	my theWeb's loadHTMLString:(my pageSource) baseURL:(missing value)
end showPage

on menuBar()
	set bar to current application's NSMenu's alloc()'s initWithTitle:""
	my addMenu(bar, "aidentity", {{"Hide aidentity", "hide:", "h"}, {"Show All", "unhideAllApplications:", ""}, {}, {"Quit aidentity", "terminate:", "q"}})
	my addMenu(bar, "Edit", {{"Undo", "undo:", "z"}, {"Redo", "redo:", "Z"}, {}, {"Cut", "cut:", "x"}, {"Copy", "copy:", "c"}, {"Paste", "paste:", "v"}, {"Select All", "selectAll:", "a"}})
	my addMenu(bar, "View", {{"Actual Size", "zoomReset:", "0", true}, {"Zoom In", "zoomIn:", "+", true}, {"Zoom In", "zoomIn:", "=", true, true}, {"Zoom Out", "zoomOut:", "-", true}})
	my addMenu(bar, "Window", {{"Minimize", "performMiniaturize:", "m"}, {"Close", "performClose:", "w"}})
	return bar
end menuBar

-- A row is a title, an action and a key. A fourth item sends the action here.
-- A fifth hides the row and keeps its key: Cmd-= is Cmd-plus without Shift.
on addMenu(bar, title, rows)
	set holder to current application's NSMenuItem's alloc()'s initWithTitle:title action:(missing value) keyEquivalent:""
	set m to current application's NSMenu's alloc()'s initWithTitle:title
	repeat with r in rows
		if (count of r) is 0 then
			m's addItem:(current application's NSMenuItem's separatorItem())
		else
			set anItem to m's addItemWithTitle:(item 1 of r) action:(item 2 of r) keyEquivalent:(item 3 of r)
			if (count of r) > 3 then anItem's setTarget:me
			if (count of r) > 4 then
				anItem's setHidden:true
				anItem's setAllowsKeyEquivalentWhenHidden:true
			end if
		end if
	end repeat
	holder's setSubmenu:m
	bar's addItem:holder
end addMenu

on zoomIn:sender
	my zoomTo((my zoomLevel) * 1.1)
end zoomIn:

on zoomOut:sender
	my zoomTo((my zoomLevel) / 1.1)
end zoomOut:

on zoomReset:sender
	my zoomTo(1.0)
end zoomReset:

on zoomTo(z)
	if z < 0.5 then set z to 0.5
	if z > 3.0 then set z to 3.0
	set my zoomLevel to z
	my theWeb's setPageZoom:z
end zoomTo

-- A request from the page: an id, "state" or "do", and up to eight plain words.
on userContentController:c didReceiveScriptMessage:m
	try
		set b to m's body()
		if not ((b's isKindOfClass:(current application's NSDictionary's |class|())) as boolean) then return
		set idv to b's objectForKey:"id"
		set reqKind to b's objectForKey:"kind"
		set args to b's objectForKey:"args"
		if idv is missing value or reqKind is missing value or args is missing value then return
		if not ((idv's isKindOfClass:(current application's NSNumber's |class|())) as boolean) then return
		set my started to true
		set stringClass to current application's NSString's |class|()
		set ok to ((reqKind's isKindOfClass:stringClass) as boolean) and ((args's isKindOfClass:(current application's NSArray's |class|())) as boolean)
		if ok then
			set k to reqKind as text
			set n to (args's |count|()) as integer
			if my driven and k is "report" and n > 0 then
				my printLine(current application's NSFileHandle's fileHandleWithStandardOutput(), (args's objectAtIndex:0))
				if n > 1 then
					current application's NSApplication's sharedApplication()'s terminate:me
				else
					my theWindow's |close|()
				end if
				return
			end if
			if k is not "state" and k is not "do" then set ok to false
			if n > 8 then set ok to false
		end if
		if ok then
			set ctl to current application's NSCharacterSet's controlCharacterSet()
			repeat with i from 0 to n - 1
				set w to args's objectAtIndex:i
				if not ((w's isKindOfClass:stringClass) as boolean) then
					set ok to false
				else if ((w's |length|()) as integer) > 1024 then
					set ok to false
				else if (|length| of (w's rangeOfCharacterFromSet:ctl)) > 0 then
					set ok to false
				end if
			end repeat
		end if
		if not ok then
			my answer(idv, -3, "")
		else if my theTask is not missing value then
			my answer(idv, -1, "")
		else
			my startTask(k, args, idv)
		end if
	on error msg
		my printLine(current application's NSFileHandle's fileHandleWithStandardError(), "request: " & msg)
	end try
end userContentController:didReceiveScriptMessage:

-- One aidentity command for the request. Its output arrives as an event, so
-- the window stays alive while the command works.
on startTask(reqKind, args, idv)
	set t to current application's NSTask's alloc()'s init()
	t's setLaunchPath:(my shellPath)
	set taskWords to current application's NSMutableArray's arrayWithArray:{my cliPath, "__window", reqKind}
	taskWords's addObjectsFromArray:args
	t's setArguments:taskWords
	set p to current application's NSPipe's pipe()
	t's setStandardOutput:p
	if reqKind is "state" then
		-- Only the JSON: a warning in it would make it unreadable.
		t's setStandardError:(current application's NSFileHandle's fileHandleWithNullDevice())
	else
		t's setStandardError:p
	end if
	t's setStandardInput:(current application's NSFileHandle's fileHandleWithNullDevice())
	set h to p's fileHandleForReading()
	current application's NSNotificationCenter's defaultCenter()'s addObserver:me selector:"taskDone:" |name|:(current application's NSFileHandleReadToEndOfFileCompletionNotification) object:h
	set my theTask to t
	set my taskKind to reqKind
	set my taskId to idv
	try
		t's |launch|()
	on error
		-- The command could not start at all: aidentity was moved, say.
		current application's NSNotificationCenter's defaultCenter()'s removeObserver:me |name|:(current application's NSFileHandleReadToEndOfFileCompletionNotification) object:h
		set my theTask to missing value
		my answer(idv, -7, "")
		return
	end try
	h's readToEndOfFileInBackgroundAndNotify()
end startTask

on taskDone:aNote
	try
		set d to (aNote's |userInfo|())'s objectForKey:(current application's NSFileHandleNotificationDataItem)
		current application's NSNotificationCenter's defaultCenter()'s removeObserver:me |name|:(current application's NSFileHandleReadToEndOfFileCompletionNotification) object:(aNote's |object|())
		set t to my theTask
		set reqKind to my taskKind
		set idv to my taskId
		set my theTask to missing value
		if t is missing value then return
		t's waitUntilExit()
		set rc to (t's terminationStatus()) as integer
		-- Ended by a signal: not an exit status of aidentity's own.
		if ((t's terminationReason()) as integer) is 2 then set rc to -6
		if reqKind is "state" and rc is 0 then
			set listing to current application's NSJSONSerialization's JSONObjectWithData:d options:1 |error|:(missing value)
			if listing is missing value then
				my answer(idv, -2, "")
			else
				set m to current application's NSMutableDictionary's dictionary()
				m's setObject:idv forKey:"id"
				m's setObject:0 forKey:"rc"
				m's setObject:listing forKey:"state"
				m's setObject:(my iconsFor(listing)) forKey:"icons"
				my tellPage("aidReply(m)", m)
			end if
		else
			set txt to current application's NSString's alloc()'s initWithData:d encoding:4
			-- Not UTF-8: read it byte for byte, which never fails.
			if txt is missing value then set txt to current application's NSString's alloc()'s initWithData:d encoding:5
			my answer(idv, rc, txt)
		end if
	on error msg
		my printLine(current application's NSFileHandle's fileHandleWithStandardError(), "answer: " & msg)
	end try
	-- The window was closed while this command ran: now it is time to go.
	if my closing then my leave()
end taskDone:

on answer(idv, rc, txt)
	set m to current application's NSMutableDictionary's dictionary()
	m's setObject:idv forKey:"id"
	m's setObject:rc forKey:"rc"
	m's setObject:txt forKey:"out"
	my tellPage("aidReply(m)", m)
end answer

-- Call the page. The answer travels as an argument, so no text of it is ever
-- read as script.
on tellPage(code, m)
	set args to missing value
	if m is not missing value then set args to current application's NSDictionary's dictionaryWithObject:m forKey:"m"
	my theWeb's callAsyncJavaScript:code arguments:args inFrame:(missing value) inContentWorld:(current application's WKContentWorld's pageWorld()) completionHandler:(missing value)
end tellPage

-- The icons the page has not been sent yet, each as a PNG the page can show.
on iconsFor(listing)
	set found to current application's NSMutableDictionary's dictionary()
	set rows to listing's objectForKey:"profiles"
	if rows is missing value then return found
	repeat with i from 0 to ((rows's |count|()) as integer) - 1
		set p to rows's objectAtIndex:i
		set k to p's objectForKey:"icon"
		set f to p's objectForKey:"iconfile"
		if k is not missing value and f is not missing value then
			if not ((my sentIcons's containsObject:k) as boolean) then
				my sentIcons's addObject:k
				set u to my iconData(f)
				if u is not missing value then found's setObject:u forKey:k
			end if
		end if
	end repeat
	return found
end iconsFor

-- A launcher's own icon file, or the icon macOS shows for it, as a 96-pixel
-- PNG (shown at 48 points).
on iconData(f)
	try
		if (f's hasSuffix:".icns") as boolean then
			set img to current application's NSImage's alloc()'s initWithContentsOfFile:f
		else
			set img to current application's NSWorkspace's sharedWorkspace()'s iconForFile:f
		end if
		if img is missing value then return missing value
		set rep to current application's NSBitmapImageRep's alloc()'s initWithBitmapDataPlanes:(missing value) pixelsWide:96 pixelsHigh:96 bitsPerSample:8 samplesPerPixel:4 hasAlpha:true isPlanar:false colorSpaceName:(current application's NSCalibratedRGBColorSpace) bytesPerRow:0 bitsPerPixel:0
		if rep is missing value then return missing value
		current application's NSGraphicsContext's saveGraphicsState()
		current application's NSGraphicsContext's setCurrentContext:(current application's NSGraphicsContext's graphicsContextWithBitmapImageRep:rep)
		img's drawInRect:(current application's NSMakeRect(0, 0, 96, 96)) fromRect:(current application's NSMakeRect(0, 0, 0, 0)) operation:2 fraction:1.0
		current application's NSGraphicsContext's restoreGraphicsState()
		set png to rep's representationUsingType:4 |properties|:(current application's NSDictionary's dictionary())
		if png is missing value then return missing value
		return (current application's NSString's stringWithString:"data:image/png;base64,")'s stringByAppendingString:(png's base64EncodedStringWithOptions:0)
	on error
		return missing value
	end try
end iconData

on windowWillClose:aNote
	if my theTask is missing value then
		my leave()
	else
		-- A command is running. Ending now would cut it off at its next line
		-- of output, half done; taskDone ends the program when it has finished.
		set my closing to true
	end if
end windowWillClose:

-- Quit, from the menu or Cmd-Q: at once (1), or, while a command runs, not
-- yet (0): the window goes, and taskDone ends the program.
on applicationShouldTerminate:sender
	if my theTask is missing value then return 1
	set my closing to true
	my theWindow's orderOut:me
	return 0
end applicationShouldTerminate:

-- Back in front: the page reads the list again, since it does not poll.
on windowDidBecomeKey:aNote
	if my started then my tellPage("aidFocus()", missing value)
end windowDidBecomeKey:

on webViewWebContentProcessDidTerminate:w
	my showPage()
end webViewWebContentProcessDidTerminate:

-- Anything loaded here that this program did not load is replaced by the page.
on webView:w didCommitNavigation:n
	if my expected then
		set my expected to false
	else
		my showPage()
	end if
end webView:didCommitNavigation:

on startCheck:t
	if not (my started) then
		set my failure to "The window's page did not start."
		my leave()
	end if
end startCheck:

-- End the event loop. It looks at "stop" only after an event, so one is sent.
on leave()
	set theApp to current application's NSApplication's sharedApplication()
	theApp's |stop|:me
	set e to current application's NSEvent's otherEventWithType:15 location:{x:0, y:0} modifierFlags:0 timestamp:0 windowNumber:0 context:(missing value) subtype:0 data1:0 data2:0
	theApp's postEvent:e atStart:true
end leave

on printLine(h, s)
	set t to (current application's NSString's stringWithFormat_("%@", s))'s stringByAppendingString:linefeed
	h's writeData:(t's dataUsingEncoding:4)
end printLine
OSA
}
