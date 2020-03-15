###############################################################################
# Purpose of script:
# Similar to the 700 script, except this is using the tiles covering CA.

geolocations.tilesCA <- data.table::fread(
  path.tilesCA, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

geolocations.tilesCA[
  , `:=` (
    groupID = .GRP,
    Latitude_groupID = floor(Latitude * 2) / 2, 
    Longitude_groupID = floor(Longitude * 1.5) / 1.5
  )
  # This partitioning yields cells on the order of 54 km x 52 km
  , by = .(
    Latitude = floor(Latitude * 2) / 2, 
    Longitude = floor(Longitude * 1.5) / 1.5
  )
]

# Make copies of Bing tiles for use in transfer learning experiment
geolocations.class <- data.table::fread(
  path.predominant_classTilesCA,
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

# This is an ad-hoc path for the computer vision experiment.
folder.predominant_class <- file.path(
  folder.data,
  'CA_Tiles_Predominant_Classes'
)

folder.partition_coarse <- file.path(
  folder.data,
  'CA_Tiles_Partition_Coarse'
)

folder.partition_coarse_color <- file.path(
  folder.data,
  'CA_Tiles_Partition_Coarse_Color'
)

# Join partition IDs
geolocations.class[
  geolocations.tilesCA
  , on = .(ID)
  , `:=` (
    Latitude = i.Latitude,
    Longitude = i.Longitude,
    groupID = groupID,
    Latitude_groupID = i.Latitude_groupID,
    Longitude_groupID = i.Longitude_groupID
  )
]

# Create source/destination paths
geolocations.class[
  , bingTilePath := file.path(
    folder.data,
    'CA_Tiles_low',
    paste0('CA_Tile_', ID, '.png')
  )
][
  , bingTilePathColor := file.path(
    folder.data,
    'CA_Tiles_low_color',
    paste0('CA_Tile_', ID, '.png')
  )
][
 , destinationPath_class := file.path(
   folder.predominant_class,
   Predominant_Class,
   paste0('CA_Tile_', ID, '.png')
 )
][
 , destinationPath_coarse := file.path(
   folder.partition_coarse,
   groupID,
   paste0('CA_Tile_', ID, '.png')
 )
][
 , destinationPath_coarse_color := file.path(
   folder.partition_coarse_color,
   groupID,
   paste0('CA_Tile_', ID, '.png')
 )
]

if(!dir.exists(folder.predominant_class)) {
  dir.create(folder.predominant_class)
}
if(!dir.exists(folder.partition_coarse)) {
  dir.create(folder.partition_coarse)
}
if(!dir.exists(folder.partition_coarse_color)) {
  dir.create(folder.partition_coarse_color)
}

# Copy/paste Bing tiles to predominant classes folder
#
# Note: This will copy ~2 GBs! Be careful about disk space.
lapply(
  geolocations.class[
    , .N
    , keyby = .(Predominant_Class)
  ][, Predominant_Class],
  function(label) {
    folder.label <- file.path(
      folder.predominant_class,
      label
    )
    
    if(!dir.exists(folder.label)) {
      dir.create(folder.label)
    }
    
    file.copy(
      from = geolocations.class[
        Predominant_Class == (label)
        , bingTilePath
      ],
      to = geolocations.class[
        Predominant_Class == (label)
        , destinationPath_class
      ]
    )
  }
)

lapply(
  geolocations.class[
    , .N
    , keyby = .(groupID)
  ][, groupID],
  function(label) {
    folder.label <- file.path(
      folder.partition_coarse,
      label
    )
    
    if(!dir.exists(folder.label)) {
      dir.create(folder.label)
    }
    
    file.copy(
      from = geolocations.class[
        groupID == (label)
        , bingTilePath
      ],
      to = geolocations.class[
        groupID == (label)
        , destinationPath_coarse
      ]
    )
  }
)

lapply(
  geolocations.class[
    , .N
    , keyby = .(groupID)
  ][, groupID],
  function(label) {
    folder.label <- file.path(
      folder.partition_coarse_color,
      label
    )
    
    if(!dir.exists(folder.label)) {
      dir.create(folder.label)
    }
    
    file.copy(
      from = geolocations.class[
        groupID == (label)
        , bingTilePathColor
      ],
      to = geolocations.class[
        groupID == (label)
        , destinationPath_coarse_color
      ]
    )
  }
)

data.table::fwrite(
  geolocations.class,
  file = path.labelsCA,
  row.names = FALSE, 
  quote = FALSE
)
