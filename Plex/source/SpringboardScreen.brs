
Function preShowSpringboardScreen(section, breadA=invalid, breadB=invalid) As Object
    if validateParam(breadA, "roString", "preShowSpringboardScreen", true) = false return -1
    if validateParam(breadB, "roString", "preShowSpringboardScreen", true) = false return -1

    port=CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
        screen.SetBreadcrumbEnabled(true)
    end if
    return screen

End Function


Function showSpringboardScreen(screen, contentList, index) As Integer
	server = contentList[index].server
	metaDataArray = Populate(screen, contentList, index)
	
    while true
        msg = wait(0, screen.GetMessagePort())
        if msg.isScreenClosed() then 
        	return -1
        else if msg.isButtonPressed() then
        	buttonCommand = metaDataArray.buttonCommands[str(msg.getIndex())]
        	print "Button command:";buttonCommand
        	if buttonCommand = "play" OR buttonCommand = "resume" then
				startTime = 0
				if buttonCommand = "resume" then
					startTime = int(val(metaDataArray.metadata.viewOffset))
				end if
        		playVideo(server, metaDataArray.metadata, metaDataArray.media, startTime)
        		'* Refresh play data after playing
        		metaDataArray = Populate(screen, contentList, index)
        	else if buttonCommand = "audioStreamSelection" then
        		SelectAudioStream(server, metaDataArray.media)
        		metaDataArray = Populate(screen, contentList, index)
        	else if buttonCommand = "subtitleStreamSelection" then
        		SelectSubtitleStream(server, metaDataArray.media)
        		metaDataArray = Populate(screen, contentList, index)
        	end if
        else if msg.isRemoteKeyPressed() then
        	'* index=4 -> left ; index=5 -> right
			if msg.getIndex() = 4 then
				index = index - 1
				if index < 0 then
					index = contentList.Count()-1
				end if
				metaDataArray = Populate(screen, contentList, index)
			else if msg.getIndex() = 5 then
				index = index + 1
				if index > contentList.Count()-1 then
					index = 0
				end if
				metaDataArray = Populate(screen, contentList, index)
			end if
        end if
    end while

    return 0
End Function

Function Populate(screen, contentList, index) As Object
	retrieving = CreateObject("roOneLineDialog")
	retrieving.SetTitle("Retrieving ...")
	retrieving.ShowBusyAnimation()
	retrieving.Show()
	content = contentList[index]
	server = content.server
    print "About to fetch meta-data for Content Type:";content.contentType
    
	metaDataArray = CreateObject("roAssociativeArray")
	metadata = server.DetailedVideoMetadata(content.sourceUrl, content.key)
	metaDataArray.metadata = metadata
	screen.AllowNavLeft(true)
	screen.AllowNavRight(true)
	screen.setContent(metadata)
	metaDataArray.media = metadata.preferredMediaItem
	metaDataArray.buttonCommands = AddButtons(screen, metadata, metadata.preferredMediaItem)
    if metadata <> invalid and metadata.SDPosterURL <> invalid and metadata.HDPosterURL <> invalid then
	    screen.PrefetchPoster(metadata.SDPosterURL, metadata.HDPosterURL)
    end if
	screen.Show()
	retrieving.Close()
	return metaDataArray
End Function

'* Show a dialog allowing user to select from all available subtitle streams
Function SelectSubtitleStream(server, media) 
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(true)
	dialog.SetTitle("Select Subtitle") 
	mediaPart = media.preferredPart
	selected = false
	for each Stream in mediaPart.streams
		if Stream.streamType = "3" AND Stream.selected <> invalid then
			selected = true
		end if
	next
	noSelectionTitle = "No Subtitles"
	if not selected then
		noSelectionTitle = "> "+noSelectionTitle
	end if
	
        buttonCommands = CreateObject("roAssociativeArray")
        buttonCount = 0
        dialog.AddButton(buttonCount, noSelectionTitle)
        buttonCommands[str(buttonCount)+"_id"] = ""
        buttonCount = buttonCount + 1
        for each Stream in mediaPart.streams
                if Stream.streamType = "3" then
                        buttonTitle = "Unknown"
                        if Stream.Language <> Invalid then
                                buttonTitle = Stream.Language
                        end if
                        if Stream.Language <> Invalid AND Stream.Codec <> Invalid AND Stream.Codec = "srt" then
                                buttonTitle = Stream.Language + " (*)"
                        else if Stream.Codec <> Invalid AND Stream.Codec = "srt" then
                                buttonTitle = "Unknown (*)"
                        end if
                        if Stream.selected <> invalid then
                                buttonTitle = "> " + buttonTitle
                        end if
                        dialog.AddButton(buttonCount, buttonTitle)
                        buttonCommands[str(buttonCount)+"_id"] = Stream.Id
                        buttonCount = buttonCount + 1   
                end if
        next
        dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
				print "Button pressed:";msg.getIndex()
        		streamId = buttonCommands[str(msg.getIndex())+"_id"]
        		print "Media part "+media.preferredPart.id
        		print "Selected subtitle "+streamId
        		server.UpdateSubtitleStreamSelection(media.preferredPart.id, streamId)
				dialog.close()
			end if 
		end if
	end while
End Function

'* Show a dialog allowing user to select from all available subtitle streams
Function SelectAudioStream(server, media) 
	port = CreateObject("roMessagePort") 
	dialog = CreateObject("roMessageDialog") 
	dialog.SetMessagePort(port)
	dialog.SetMenuTopLeft(true)
	dialog.EnableBackButton(true)
	dialog.SetTitle("Select Audio Stream") 
	mediaPart = media.preferredPart
	buttonCommands = CreateObject("roAssociativeArray")
	buttonCount = 0
        for each Stream in mediaPart.streams
                if Stream.streamType = "2" then
                        buttonTitle = "Unkwown"
                        if Stream.Language <> Invalid then
                                buttonTitle = Stream.Language
                        end if
                        subtitle = invalid
                        if Stream.Codec <> invalid then
                                if Stream.Codec = "dca" then
                                        subtitle = "DTS"
                                else 
                                        subtitle = ucase(Stream.Codec)
                                end if
                        end if
                        if Stream.Channels <> invalid then
                                if Stream.Channels = "2" then
                                        subtitle = subtitle + " Stereo"
                                else if Stream.Channels = "6" then
                                        subtitle = subtitle + " 5.1"
                                else if Stream.Channels = "8" then
                                        subtitle = subtitle + " 7.1"
                                end if
                        end if
                        if subtitle <> invalid then
                                buttonTitle = buttonTitle + " ("+subtitle+")"
                        end if
                        if Stream.selected <> invalid then
                                buttonTitle = "> " + buttonTitle
                        end if
                        dialog.AddButton(buttonCount, buttonTitle)
                        buttonCommands[str(buttonCount)+"_id"] = Stream.Id
                        buttonCount = buttonCount + 1   
                end if
        next
        dialog.Show()
	while true 
		msg = wait(0, dialog.GetMessagePort()) 
		if type(msg) = "roMessageDialogEvent"
			if msg.isScreenClosed() then
				dialog.close()
				exit while
			else if msg.isButtonPressed() then
        		streamId = buttonCommands[str(msg.getIndex())+"_id"]
        		print "Media part "+media.preferredPart.id
        		print "Selected audio stream "+streamId
        		server.UpdateAudioStreamSelection(media.preferredPart.id, streamId)
				dialog.close()
			end if 
		end if
	end while
End Function

Function AddButtons(screen, metadata, media) As Object

	buttonCommands = CreateObject("roAssociativeArray")
	screen.ClearButtons()
	buttonCount = 0
	if metadata.viewOffset <> invalid then
		intervalInSeconds = fix(val(metadata.viewOffset)/(1000))	
		resumeTitle = "Resume from "+TimeDisplay(intervalInSeconds)
		screen.AddButton(buttonCount, resumeTitle)
		buttonCommands[str(buttonCount)] = "resume"
		buttonCount = buttonCount + 1
	end if
	screen.AddButton(buttonCount, "Play")
	buttonCommands[str(buttonCount)] = "play"
	buttonCount = buttonCount + 1
	
	mediaPart = media.preferredPart
	subtitleStreams = []
	audioStreams = []
	for each Stream in mediaPart.streams
		if Stream.streamType = "2" then
			audioStreams.Push(Stream)
		else if Stream.streamType = "3" then
			subtitleStreams.Push(Stream)
		end if
	next
	print "Found audio streams:";audioStreams.Count()
	print "Found subtitle streams:";subtitleStreams.Count()
	if audioStreams.Count() > 1 then
		screen.AddButton(buttonCount, "Select audio stream")
		buttonCommands[str(buttonCount)] = "audioStreamSelection"
		buttonCount = buttonCount + 1
	end if
	if subtitleStreams.Count() > 0 then
		screen.AddButton(buttonCount, "Select subtitles")
		buttonCommands[str(buttonCount)] = "subtitleStreamSelection"
		buttonCount = buttonCount + 1
	end if
	return buttonCommands
End Function

Function TimeDisplay(intervalInSeconds) As String
	hours = fix(intervalInSeconds/(60*60))
	remainder = intervalInSeconds - hours*60*60
	minutes = fix(remainder/60)
	seconds = remainder - minutes*60
	hoursStr = hours.tostr()
	if hoursStr.len() = 1 then
		hoursStr = "0"+hoursStr
	end if
	minsStr = minutes.tostr()
	if minsStr.len() = 1 then
		minsStr = "0"+minsStr
	end if
	secsStr = seconds.tostr()
	if secsStr.len() = 1 then
		secsStr = "0"+secsStr
	end if
	return hoursStr+":"+minsStr+":"+secsStr
End Function

