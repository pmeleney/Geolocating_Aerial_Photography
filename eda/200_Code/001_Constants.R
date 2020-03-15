folder.data <- '100_Data'
folder.code <- '200_Code'
folder.markdown <- '300_Markdown'

degreesToRadians <- pi/180

# Define bounding coordinates for US and California.
# US bounding box comes from here: https://gist.github.com/jsundram/1251783
# CA bounding box comes from here: 
#   https://anthonylouisdagostino.com/bounding-boxes-for-all-us-states/
boundingLat.US <- c(24.7433195, 49.3457868)
boundingLon.US <- c(-124.7844079, -66.9513812)
boundingLat.CA <- c(32.534156, 42.009518) 
boundingLon.CA <- c(-124.409591, -114.131211)

# Factor indices used by NLCD that map to land cover classifications
indices.nlcd <- as.character(
  c(
    0, 11, 12, 21:24, 31, 41:43, 51:52, 71:74, 81:82, 90, 95
  )
)

# Level names for NLCD classifications
levels.nlcd <- c(
  'Unclassified',
  'Open_Water',
  'Perennial_Ice_Snow',
  'Developed_Open_Space',
  'Developed_Low_Intensity',
  'Developed_Medium_Intensity',
  'Developed_High_Intensity',
  'Barren_Land',
  'Deciduous_Forest',
  'Evergreen_Forest',
  'Mixed_Forest',
  'Dwarf_Scrub',
  'Shrub',
  'Grassland',
  'Sedge',
  'Lichens',
  'Moss',
  'Pasture',
  'Cultivated_Crops',
  'Woody_Wetlands',
  'Emergent_Herbaceous_Wetlands'
)
