# Raw geolocations
filename.geolocations <- 'AllFlightsAOR.csv'
path.geolocations <- file.path(
  folder.data,
  filename.geolocations
)

# Selected geolocations
filename.selected_geolocations <- '200_Selected_Geolocations.csv'
path.selected_geolocations <- file.path(
  folder.data,
  filename.selected_geolocations
)

# NLCD image file
name.nlcd <- 'NLCD_2016_Land_Cover_L48_20190424'
filename.nlcd <- paste0(name.nlcd, '.img')
folder.nlcd <- file.path(
  folder.data,
  name.nlcd
)
path.nlcd <- file.path(
  folder.nlcd,
  filename.nlcd
)

# Image dimensions
filename.dimensions <- 'image_dimensions.csv'
path.dimensions <- file.path(
  folder.data,
  filename.dimensions
)

# Selected geolocations with NLCD classification proportions
filename.classes <- '300_Geolocation_Land_Cover_Classifications.csv'
path.classes <- file.path(
  folder.data,
  filename.classes
)

# Predominant land cover classifications
filename.predominant_class <- '600_Geolocations_Predominant_Classifications.csv'
path.predominant_class <- file.path(
  folder.data,
  filename.predominant_class
)

# Tiles spanning Californina
filename.tilesCA <- '800_California_Partition_IDs.csv'
path.tilesCA <- file.path(
  folder.data,
  filename.tilesCA
)

# NLCD classification proportions of tiles spanning Californina
filename.classesTilesCA <- '1000_California_Land_Cover_Classifications.csv'
path.classesTilesCA <- file.path(
  folder.data,
  filename.classesTilesCA
)

# Predominant land cover classifications of tiles spanning Californina
filename.predominant_classTilesCA <- '1100_California_Predominant_Classifications.csv'
path.predominant_classTilesCA <- file.path(
  folder.data,
  filename.predominant_classTilesCA
)

# Partition IDs and predominant land cover classifications of tiles spanning 
# Californina
filename.labelsCA <- '1200_California_Labels.csv'
path.labelsCA <- file.path(
  folder.data,
  filename.labelsCA
)

# Classified aerial photos from CNN
filename.cnn_results <- '1300_Aerial_Photo_Partition_Classifications.csv'
path.cnn_results <- file.path(
  folder.data,
  filename.cnn_results
)
