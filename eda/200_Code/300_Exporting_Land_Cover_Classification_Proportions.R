###############################################################################
# Purpose of script:
# Calculate proportion of landcover classifications from the National Landcover
# Database in a region determined by the dimensions of the associated image, and
# then export the results.

# Note: In prior scripts, the object "geolocations" included a larger set of
# geolocations. Going forward, "geolocations" will refer to the selected
# geolocations described in 200_Exporting_Selected_Geolocations.
#
# Import selected geolocations
geolocations <- data.table::fread(
  path.selected_geolocations, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

# Check if the NLCD raster is available. Prompt user if not.
if(!file.exists(path.nlcd)) {
  promptUserForNLCD()
}

# Import NLCD img raster
raster.nlcd <- raster::raster(path.nlcd)

# Get shapefile of US at county level and then subset the California counties
shapefile.us <- raster::getData('GADM', country = 'usa', level = 2)
shapefile.ca <- raster::subset(shapefile.us, NAME_1 == 'California')

# Transform the geolocations into SpatialPoints, get a subset of the california
# shapefile corresponding to the geolocations, and get a subset of the NLCD
# raster that contains the geolocations.
list.raster.geolocations <- getRasterSubset(
  locations = geolocations,
  shapefileData = shapefile.ca,
  rasterData = raster.nlcd
)

###############################################################################
## Restate NLCD and geolocation data for ease in extracting land cover
## classifications.

# Cast the on-disc cropped raster to an in-memory matrix.
#
# Note: This requires a few GBs of RAM! Brute force approach...
matrix.nlcd.geolocations <- raster::as.matrix(
  list.raster.geolocations[['raster_subset']]
)

gc()

geolocations.transformed <- convertExtentToIndices(
  listRaster = list.raster.geolocations
)

# Append radius for each image.
#
# Note: Although a direct join isn't easy to setup, the image order should
# equal to that in geolocations. So appending the column as-is should be ok.
geolocations.transformed[
  , Radius := geolocations[['Radius']]
]

###############################################################################
## Calculate proportion of NLCD integer classification in a radius around each
## geolocation consistent with its image dimensions.

# Create row id on which to do row-level calculations
geolocations.transformed[
  , rowID := 1:.N
]

# Calculate land cover classification proportions for each selected geolocation
#
# Note: The following function (and most of this script) is an ad-hoc way of
# approximating:
#
# 
geolocations.transformed[
  , (indices.nlcd) := extractLandCoverFreq(
    lat.index = Latitude.index, 
    lon.index = Longitude.index, 
    sideLength = Radius,
    matNLCD = matrix.nlcd.geolocations
  )
  , by = .(rowID)
]

# Restate the factor levels to formal NLCD classification names
data.table::setnames(
  geolocations.transformed,
  indices.nlcd,
  levels.nlcd
)

# Replace NA's with 0's
geolocations.transformed[
  , (levels.nlcd) := lapply(
    (levels.nlcd), function(landcover)
    ifelse(is.na(get(landcover)), 0, get(landcover))
  )
]

###############################################################################
## Append land cover proportions to selected geolocations

# Create row id to use as join predicate, since the row order did not change
geolocations[
  , rowID := 1:.N
]

geolocations[
  geolocations.transformed
  , on = .(rowID)
  , (levels.nlcd) := mget(levels.nlcd)
]

###############################################################################
## Inspect land cover extraction process by visualization

# Warning, plotFlightLandCoverProportions will plot all geolocations for a 
# input flight! This could over a thousand for some flights, which may take long
# to return the formatted map or be slow when using the map. You can tailor this 
# by selecting a subset of geolocations for the input flight in the 
# imageGeolocations parameter.
#
# E.g., 
# geolocations[
#   FlightID == 'BUT_1958' & 
#     OBJECTID %in% SOME_GEOLOCATION_SuBSET
# ]

# E.g. for flight BUT_1958
plotFlightLandCoverProportions(
  flightID = 'BUT_1958',
  imageGeolocations = geolocations,
  shapefileData = shapefile.ca,
  rasterData = list.raster.geolocations[['raster_subset']],
  maxMegabyte = 10
)

###############################################################################
## Export results

data.table::fwrite(
  geolocations, 
  file = path.classes,
  row.names = FALSE, 
  quote = FALSE
)
