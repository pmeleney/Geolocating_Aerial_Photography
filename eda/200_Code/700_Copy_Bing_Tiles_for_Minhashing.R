###############################################################################
# Purpose of script:
# This is an ad-hoc script to experiment with a computer vision / LSH method
# that compares hashed image features against a hashed database of reference
# images. The reference images are Bing tiles with locations approximately 
# equal to those from aerial image, i.e., the output from the 400 script. 
# These Bing tiles are copied into folders according to their predominant land
# cover classification inferred from the 600 script. The goal is for these
# predominant classes to act as categories to train a CNN using transfer 
# learning from a Resnet model.

# Make copies of Bing tiles for use in transfer learning experiment
geolocations.class <- data.table::fread(
  path.predominant_class,
  ep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

# This is an ad-hoc path for the computer vision experiment.
folder.experiment <- file.path(
  'C:\\Users\\willf\\Documents\\Data_Science',
  'aerial_photo_lsh\\bing_tiles_original'
)

# Create source/destination path
geolocations.class[
  , bingTilePath := file.path(
    folder.data, 
    FlightID, 
    paste0(FlightID, '_', Frame, '.png')
  )
][
 , destinationPath := file.path(
   folder.experiment,
   Predominant_Class,
   paste0(FlightID, '_', Frame, '.png')
 )
]

# Copy/paste Bing tiles to minhashing folder
#
# Note: This will copy ~172 GBs! Be careful about disk space.
lapply(
  # Only copy geolocations with predominant classes having at least 100
  # total geolocations.
  geolocations.class[
    , .N
    , keyby = .(Predominant_Class)
  ][N > 100, Predominant_Class],
  function(predClass) {
    folder.predClass <- file.path(
      folder.experiment,
      predClass
    )
    
    if(!dir.exists(folder.predClass)) {
      dir.create(folder.predClass)
    }
    
    file.copy(
      from = geolocations.class[
        Predominant_Class == (predClass)
        , bingTilePath
      ],
      to = geolocations.class[
        Predominant_Class == (predClass)
        , destinationPath
      ]
    )
  }
)
