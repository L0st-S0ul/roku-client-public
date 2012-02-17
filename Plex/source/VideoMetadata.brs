
Function newVideoMetadata(server, sourceUrl, xmlContainer, videoItemXml) As Object
	return construct(server, sourceUrl, xmlContainer, videoItemXml, false)
End Function

Function newDetailedVideoMetadata(server, sourceUrl, xmlContainer, videoItemXml) As Object
	return construct(server, sourceUrl, xmlContainer, videoItemXml, true)
End Function

Function construct(server, sourceUrl, xmlContainer, videoItemXml, detailed) As Object
	
	rokuMetadata = ConstructRokuVideoMetadata(server, sourceUrl, xmlContainer, videoItemXml, detailed)
	rokuMetadata.media = ParseVideoMedia(videoItemXml)
	rokuMetadata.preferredMediaItem = PickMediaItem(rokuMetadata.media)
	
	rokuMetadata.server = server
	rokuMetadata.sourceUrl = sourceUrl
	return rokuMetadata
End Function

Function ConstructRokuVideoMetadata(server, sourceUrl, xmlContainer, videoItemXml, detailed as boolean) As Object
	video = CreateObject("roAssociativeArray")
	
	video.mediaContainerIdentifier = xmlContainer@identifier
	video.ratingKey = videoItemXml@ratingKey
	video.ContentType = videoItemXml@type
	if video.ContentType = invalid then
		'* treat video items with no content type as clips
		video.ContentType = "clip" 
	end if
	video.Title = videoItemXml@title
	video.Key = videoItemXml@key
	
	video.ShortDescriptionLine1 = videoItemXml@title
	' for performance reasons we need to make sure the description is not huge. seems to cause memory recall issues
	if videoItemXml@summary <> invalid then
        if len(videoItemXml@summary) > 180 then
		    video.Description = left(videoItemXml@summary, 180)+"..."
	    else
		    video.Description = videoItemXml@summary
        end if
    else
        video.Description = "(No summary available)"
	end if
	video.ReleaseDate = videoItemXml@originallyAvailableAt
	video.viewOffset = videoItemXml@viewOffset
	video.viewCount = videoItemXml@viewCount
	
	length = videoItemXml@duration
	if length <> invalid then
		video.Length = int(val(length)/1000)
		video.RawLength = val(length)
	end if
	
	if video.viewCount <> invalid AND val(video.viewCount) > 0 then
		video.Watched = true
	else
		video.Watched = false
	end if
	' if a video has ever been watch mark as such, else mark partially if there's a recorded
	' offset
	if video.Watched then
		video.ShortDescriptionLine1 = video.ShortDescriptionLine1 + " (Watched)"
	else if video.viewOffset <> invalid AND val(video.viewOffset) > 0 then
		video.ShortDescriptionLine1 = video.ShortDescriptionLine1 + " (Partially Watched)"
	end if
	' Bookmark position represents the last watched so a video could be marked watched but
	' have a bookmark not at the end if it was a subsequent viewing
	video.BookmarkPosition = 0
	if video.viewOffset <> invalid AND val(video.viewOffset) > 0 then
		video.BookmarkPosition = int(val(video.viewOffset)/1000)
	else if video.Watched AND length <> invalid then
		video.BookmarkPosition = int(val(length)/1000)
	end if
	
	if videoItemXml@tagline <> invalid then
		video.ShortDescriptionLine2 = videoItemXml@tagline
	end if
	if videoItemXml@sourceTitle <> invalid then
		video.ShortDescriptionLine2 = videoItemXml@sourceTitle
	end if
	if xmlContainer@viewGroup = "episode" then
        if videoItemXml@grandparentTitle <> invalid then
            video.ShortDescriptionLine1 = videoItemXml@grandparentTitle + ": " + video.ShortDescriptionLine1
            video.Title = video.ShortDescriptionLine1
        end if
		video.EpisodeNumber = videoItemXml@index
		if videoItemXml@parentIndex <> invalid then
			video.ShortDescriptionLine2 = "Season " + videoItemXml@parentIndex +" - Episode "+videoItemXml@index
		else
			video.ShortDescriptionLine2 = "Episode "+videoItemXml@index
		end if
		if video.ReleaseDate <> invalid then
			video.ShortDescriptionLine2 = video.ShortDescriptionLine2 + " - " + video.ReleaseDate
		end if
	end if
	if xmlContainer@viewGroup = "Details" OR xmlContainer@viewGroup = "InfoList" then
		video.ShortDescriptionLine2 = videoItemXml@summary
	end if
	if detailed then
		video.Rating = videoItemXml@contentRating
		rating = videoItemXml@rating
		if rating <> invalid then
			video.StarRating = int(val(rating)*10)
		end if
		video.Actors = CreateObject("roArray", 15, true)
		for each Actor in videoItemXml.Role
			video.Actors.Push(Actor@tag)
		next
		video.Director = CreateObject("roArray", 3, true)
		for each Director in videoItemXml.Director
			video.Director.Push(Director@tag)
		next
		video.Categories = CreateObject("roArray", 15, true)
		for each Category in videoItemXml.Genre
			video.Categories.Push(Category@tag)
		next
		
		' TODO: review the logic here. Last media item wins. Is this what we want?
		' TODO: comment out HD for now - does it fix the SD playing regression?
		for each MediaItem in videoItemXml.Media
			'videoResolution = MediaItem@videoResolution
			'if videoResolution = "1080" OR videoResolution = "720" then
			'	video.IsHD = true
			'	video.HDBranded = true
			'end if
			'if videoResolution = "1080" then
			'	video.FullHD = true
			'end if
			frameRate = MediaItem@videoFrameRate
			if frameRate <> invalid then
				if frameRate = "24p" then
					video.FrameRate = 24
				else if frameRate = "NTSC"
					video.FrameRate = 30
				end if
			end if
		next
	end if
	sizes = ImageSizes(xmlContainer@viewGroup, video.ContentType)
	thumb = videoItemXml@thumb
	if thumb <> invalid then
		video.SDPosterURL = server.TranscodedImage(sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		video.HDPosterURL = server.TranscodedImage(sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = videoItemXml@art
		if art = invalid then
			art = xmlContainer@art
		end if
		if art <> invalid then
			video.SDPosterURL = server.TranscodedImage(sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			video.HDPosterURL = server.TranscodedImage(sourceUrl, art, sizes.hdWidth, sizes.hdHeight)	
		end if
	end if
	return video
End Function

Function ParseVideoMedia(videoItem) As Object
    mediaArray = CreateObject("roArray", 5, true)
	for each MediaItem in videoItem.Media
		media = CreateObject("roAssociativeArray")
		media.indirect = false
		if MediaItem@indirect <> invalid AND MediaItem@indirect = "1" then
			media.indirect = true
		end if
		media.identifier = MediaItem@id
		media.audioCodec = MediaItem@audioCodec
		media.videoCodec = MediaItem@videoCodec
		media.videoResolution = MediaItem@videoResolution
		media.container = MediaItem@container
		media.parts = CreateObject("roArray", 3, true)
		for each MediaPart in MediaItem.Part
			part = CreateObject("roAssociativeArray")
			part.id = MediaPart@id
			part.key = MediaPart@key
			part.streams = CreateObject("roArray", 5, true)
			for each StreamItem in MediaPart.Stream
				stream = CreateObject("roAssociativeArray")
				stream.id = StreamItem@id
				stream.streamType = StreamItem@streamType
				stream.codec = StreamItem@codec
				stream.language = StreamItem@language
				stream.selected = StreamItem@selected
				stream.channels = StreamItem@channels
				part.streams.Push(stream)
			next
			media.parts.Push(part)
		next
		'* TODO: deal with multiple parts correctly. Not sure how audio etc selection works
		'* TODO: with multi-part
		media.preferredPart = media.parts[0]
		mediaArray.Push(media)
	next
	return mediaArray
End Function

'* Logic for choosing which Media item to use from the collection of possibles.
Function PickMediaItem(mediaItems) As Object
	if mediaItems.count()  = 0 then
		return mediaItems[0]
	else
		return mediaItems[0]
	end if
End Function

