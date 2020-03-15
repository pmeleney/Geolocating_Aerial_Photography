# Import selected geolocations
geolocations <- data.table::fread(
  path.selected_geolocations, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

bingMapsURL <- 'https://dev.virtualearth.net/REST/v1/Imagery/Map/Aerial/'

bingTiles <- geolocations[
  order(FlightID, Frame)
  , .(
    FlightID,
    Frame,
    bingTile = paste0(
      bingMapsURL, 
      Latitude, ',', Longitude, 
      '/15?mapSize=1500,1500',
      '&format=png',
      '&key=Ajp6dNSu2Nklt1nAzKR2tWghVH-wgSufSMCYtt993bKrIM6tbh8fl26vi2Y76VMo'
    )
  )
][
  , bingTile
]

tileNames <- geolocations[
  order(FlightID, Frame)
  , paste0(FlightID, '_', Frame, '.png')
]

folderNames <- geolocations[
  order(FlightID, Frame)
  , FlightID
]

data.table::setorder(geolocations, FlightID, Frame)
geolocations[, tileID := 1:.N]

lapply(
  seq_along(tileNames),
  function(index) {
    folderPath <- file.path(
      folder.data,
      folderNames[index]
    )
    
    pngPath <- file.path(
      folderPath,
      tileNames[index]
    )
    
    if(!dir.exists(folderPath)) {
      dir.create(folderPath)
    }
    
    tryCatch(
      download.file(
        bingTiles[index], 
        destfile = pngPath, 
        quiet = TRUE,
        mode = 'wb'
      ), 
      error = function(e) geolocations[tileID == index, failInd := TRUE]
    )
    
    geolocations[tileID == index, completionInd := TRUE]
  }
)
