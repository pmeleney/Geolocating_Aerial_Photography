# This grid gives ~1500 m N-S and ~3000 m E-W
gridCA.lat <- seq(
  from = boundingLat.CA[1], 
  to = boundingLat.CA[2], 
  length.out = 645
)
gridCA.lon <- seq(
  from = boundingLon.CA[1], 
  to = boundingLon.CA[2], 
  length.out = 300
)
gridCA <- data.table::as.data.table(expand.grid(gridCA.lat, gridCA.lon))[
  , ID := 1:.N
]

data.table::setkey(gridCA, ID)

data.table::setnames(
  gridCA,
  c('Var1', 'Var2'),
  c('Latitude', 'Longitude')
)

shapefile.us <- raster::getData('GADM', country = 'usa', level = 2)
shapefile.ca <- raster::subset(shapefile.us, NAME_1 == 'California')
raster.nlcd <- raster::raster(path.nlcd)

# Find intersection of points within CA shapefile to exclude points outside CA
gisSubset <- getShapefileSubset(
 locations = gridCA, 
 shapefileData = shapefile.ca, 
 crs = sp::CRS(raster.nlcd@crs@projargs)
)

shapefile.intersection <- 
  gisSubset[['shapefile_intersection']]

data.table::setDT(shapefile.intersection)

shapefile.intersection[
  , ID := 1:.N
]

gridCA.intersection <- gridCA[
  shapefile.intersection[!is.na(GID_1), .(ID)]
  , on = .(ID)
  , nomatch = FALSE
]

# Export grid of locations spanning CA
data.table::fwrite(
  gridCA.intersection, 
  file = path.tilesCA,
  row.names = FALSE, 
  quote = FALSE
)

bingMapsURL <- 'https://dev.virtualearth.net/REST/v1/Imagery/Map/Aerial/'

bingTiles <- gridCA.intersection[
  , .(
    bingTile = paste0(
      bingMapsURL, 
      Latitude, ',', Longitude, 
      '/15?mapSize=1500,1500',
      '&format=png',
      # Note: This key is no disabled.
      '&key=Ajp6dNSu2Nklt1nAzKR2tWghVH-wgSufSMCYtt993bKrIM6tbh8fl26vi2Y76VMo'
    )
  )
][
  , bingTile
]

tileNames <- gridCA.intersection[
  , paste0('CA_Tile_', ID, '.png')
]

folderPath <- file.path(
  folder.data,
  'CA_Tiles'
)

if(!dir.exists(folderPath)) {
  dir.create(folderPath)
}

# Note: This loop will downloaded ~400 GBs of satellite tiles!
# Beware...
lapply(
  seq_along(tileNames),
  function(index) {
    pngPath <- file.path(
      folderPath,
      tileNames[index]
    )
    
    tryCatch(
      download.file(
        bingTiles[index], 
        destfile = pngPath, 
        quiet = TRUE,
        mode = 'wb'
      ), 
      error = function(e) 
        gridCA.intersection[.(index), failInd := TRUE]
    )
    
    gridCA.intersection[.(index), completionInd := TRUE]
  }
)
