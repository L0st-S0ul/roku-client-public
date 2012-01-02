
Function newDirectoryMetadata(server, sourceUrl, xmlContainer, directoryItemXml) As Object
	rokuMetadata = ConstructDirectoryMetadata(server, sourceUrl, xmlContainer, directoryItemXml)
	
	rokuMetadata.server = server
	rokuMetadata.sourceUrl = sourceUrl
	rokuMetadata.viewGroup = xmlContainer@viewGroup
	return rokuMetadata
End Function


Function ConstructDirectoryMetadata(server, sourceUrl, xmlContainer, directoryItemXml) As Object	
	directory = CreateObject("roAssociativeArray")
	directory.type  = directoryItemXml@type
	directory.ContentType = directoryItemXml@type
	if directory.ContentType = "show" then
		directory.ContentType = "series"
	else if directory.ContentType = invalid then
		directory.ContentType = "appClip"
	end if
	directory.Key = directoryItemXml@key
	directory.Title = directoryItemXml@title
	if directoryItemXml@summary <> invalid then
        if len(directoryItemXml@summary) > 180 then
		    directory.Description = left(directoryItemXml@summary, 180)+"..."
	    else
		    directory.Description = directoryItemXml@summary
        end if
    else
        directory.Description = "(No summary available)"
	end if
	
	if directory.Title = invalid then
		directory.Title = directoryItemXml@name
	end if
	directory.ShortDescriptionLine1 = directoryItemXml@title
	if directory.ShortDescriptionLine1 = invalid then
		directory.ShortDescriptionLine1 = directoryItemXml@name
	end if
	if directoryItemXml@summary <> invalid then
        if len(directoryItemXml@summary) > 180 then
		    directory.ShortDescriptionLine2 = left(directoryItemXml@summary, 180)+"..."
	    else
		    directory.ShortDescriptionLine2 = directoryItemXml@summary
        end if
    else
        'directory.ShortDescriptionLine2 = "(No summary available)"
	end if
	
	'if xmlResponse.xml@viewGroup = "Details" OR xmlResponse.xml@viewGroup = "InfoList" then
	'	video.ShortDescriptionLine2 = videoItem@summary
	'end if
	
	sizes = ImageSizes(xmlContainer@viewGroup, directory.ContentType)
	thumb = directoryItemXml@thumb
	if thumb <> invalid and thumb <> "" then
		directory.SDPosterURL = server.TranscodedImage(sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		directory.HDPosterURL = server.TranscodedImage(sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = directoryItemXml@art
		if art = invalid then
			art = xmlContainer@art
		end if
		if art <> invalid then
			directory.SDPosterURL = server.TranscodedImage(sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			directory.HDPosterURL = server.TranscodedImage(sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
		end if
	end if
	return directory
End Function
