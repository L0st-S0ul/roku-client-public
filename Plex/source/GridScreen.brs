'*
'* Initial attempt at a grid screen. 
'*
Function preShowGridScreen() As Object
	Print "##################################### CREATE GRID SCREEN #####################################"
	m.port = CreateObject("roMessagePort")
    grid = CreateObject("roGridScreen")
	grid.SetMessagePort(m.port)
		
    grid.SetDisplayMode("photo-fit")
	grid.SetUpBehaviorAtTopRow("exit")
	
    return grid
End Function

Function showGridScreen(grid, content) As Integer
	if validateParam(grid, "roGridScreen", "showGridScreen") = false return -1
    if validateParam(content, "roAssociativeArray", "showGridScreen") = false return -1			

	totalTimer = CreateObject("roTimespan")
	totalTimer.Mark()
	
	performanceTimer = CreateObject("roTimespan")
	
	server = content.server
	contentKey = content.key
	currentTitle = content.Title
	
	performanceTimer.Mark()
	queryResponse = server.GetQueryResponse(content.sourceUrl, contentKey)
	Print "SERVER TIMER -- Initial Server Query took: " + itostr(performanceTimer.TotalMilliseconds())
	
	performanceTimer.Mark()
	names = server.GetListNames(queryResponse)
	Print "PARSER TIMER -- GetListNames took: " + itostr(performanceTimer.TotalMilliseconds())
	
	performanceTimer.Mark()
	keys = server.GetListKeys(queryResponse)
	Print "PARSER TIMER -- GetListKeys took: " + itostr(performanceTimer.TotalMilliseconds())
	
	performanceTimer.Mark()
    grid.SetupLists(names.Count()) 
	Print "GRID TIMER -- SetupLists took: " + itostr(performanceTimer.TotalMilliseconds())
	
	performanceTimer.Mark()
	grid.SetListNames(names)
	Print "GRID TIMER -- SetListNames took: " + itostr(performanceTimer.TotalMilliseconds())
	
	' Show the grid...
	grid.Show()
	
	' How many rows we have
	keyCount = keys.Count()
	'print "Keys for loader: ";keys
	
	' Our content array holder
	contentArray = []
	
	rowCount = 0	
	' Load the first grid row...
	performanceTimer.Mark()
	rowCount = loadNextRow(grid, server, keys[rowCount], queryResponse.sourceUrl, contentArray, rowCount)
	Print "ROW LOADER -- First row took: " + itostr(performanceTimer.TotalMilliseconds())
	' Load the second grid row...
	'performanceTimer.Mark()
	'rowCount = loadNextRow(grid, server, keys[rowCount], queryResponse.sourceUrl, contentArray, rowCount)	
	'Print "ROW LOADER -- Second row took: " + itostr(performanceTimer.TotalMilliseconds())
	
	Print "TOTAL INITIAL GRID LOAD TIME: " + itostr(totalTimer.TotalMilliseconds())
	
	while true
        msg = wait(1, m.port)
		
        if type(msg) = "roGridScreenEvent" then
            if msg.isListItemSelected() then
				print "Selected msg: ";msg.GetData()
				row = msg.GetIndex()
				if row < rowCount then
					selection = msg.getData()
					
					contentSelected = contentArray[row][selection]
					contentType = contentSelected.ContentType

					if contentType = "movie" OR contentType = "episode" then
						displaySpringboardScreen(contentSelected.title, contentArray[row], selection)
					else if contentType = "clip" then
						playPluginVideo(server, contentSelected)
					else if contentSelected.viewGroup <> invalid AND contentSelected.viewGroup = "Store:Info" then
						ChannelInfo(contentSelected)
					else
						'showNextGridScreen(contentSelected.title, contentSelected)
						showNextPosterScreen(contentSelected.title, contentSelected)
					end if
				end if
            else if msg.isScreenClosed() then
				Print "prepare to close gridscreen: " + currentTitle
				Print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ CLOSE GRID SCREEN ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                return -1
            end if
		else
			'print "Unknown event: ";msg
        end if
		
		' check to see if there is more data to load and do one at a time...
		if( rowCount < keyCount )
			performanceTimer.Mark()
			rowCount = loadNextRow(grid, server, keys[rowCount], queryResponse.sourceUrl, contentArray, rowCount)
			Print "PROGRESSIVE ROW LOADER -- row took: " + itostr(performanceTimer.TotalMilliseconds())
		end if
    end while
	return 0
End Function

Function loadNextRow(myGrid, myServer, myKey, mySourceUrl, myContentArray, myRowCount) as Integer
	performanceTimer = CreateObject("roTimespan")
	performanceTimer.Mark()
	
	'print "myKey: ";myKey
	response = myServer.GetQueryResponse(mySourceUrl, myKey)
	'printXML(response.xml, 1)
	Print "PAGE CONTENT TIMER -- Getting Row Content took: " + itostr(performanceTimer.TotalMilliseconds())

	performanceTimer.Mark()
	contentList = myServer.GetContent(response)
	Print "PAGE CONTENT TIMER -- Parsing Server Content took: " + itostr(performanceTimer.TotalMilliseconds())
			
	myContentArray[myRowCount] = []
	
	performanceTimer.Mark()
	itemCount = 0
	for each item in contentList
		myContentArray[myRowCount][itemCount] = item
		itemCount = itemCount + 1
	next

	if itemCount > 0 then
		myGrid.setContentList(myRowCount, myContentArray[myRowCount])
	else
		myGrid.setListVisible(myRowCount, false)
	end if
			
	myRowCount = myRowCount + 1
	
	return myRowCount
End Function

Function showNextGridScreen(currentTitle, selected As Object) As Dynamic
    if validateParam(selected, "roAssociativeArray", "showNextGridScreen") = false return -1
    grid = preShowGridScreen()
    showGridScreen(grid, selected)
    return 0
End Function