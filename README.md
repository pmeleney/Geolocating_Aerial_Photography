# Geolocating Aerial Photography

## Find North

The purpose of this Jupyter Notebook is to determine the orientation of two geo-located aerial photographs.  The main function is FindNorth.find_north().  It takes the location of two .tif image files, two tuples describing the lat and long of the centerpoints of those images, and a string ("SIFT". "ORB", or "BRISK") which determines which feature descriptor is used to determine the location of keypoints in the input images.  Opencv-python 3.4.2.17 and opencv-contrib-python 3.4.2.17 or earlier are required to run the "SIFT" algorithm.

To run the demo script call the function with any two consecutive images found in demo/find_north/images/c-300/.  For images c-300_a-1.tif and c-300_a-2.tif the returned rotations to true north should be 11.33 degrees and 9.78 degrees respectively.


## Topo Compare

## pix2pix Generative Adversarial Network

The git repository is not large enough to store all of the training images needed to recreate the GAN models from our paper. However we have included a zipped repository of Jun-Yan Zhu one of the authors of the original pix2pix GAN paper and is easier to use than Philip Isola’s repo. The jupyter notebooks and scripts needed to train and test a pix2pix GAN is included in the zip. Also in the zip is code for a cycle GAN which is similar to a pix2pix however, the cycle GAN does not use paired images as it is not a conditional network. The zip has a script to join training and target images into a single input file for the pix2pix. For our purposes we joined the aerial images and the matching satellite images. When joining images they need to be the same dimensions (same size, number of channels and type), so some reformatting may need to be done. Two good options for reformatting images are the Pillow and GDAL packages; Pillow is standard with Anaconda installs and GDAL must be either pip or conda installed.  Some of our images were in unusual formats that Pillow could not open however GDAL was able to handle conversion of these files to more standard formats. To run the join script you will have to make A and B directories each with train, test, and val sub directories. To make it easy, put the input images into the A folders and the target images into the B folders. Then when training select AtoB as the direction. The training script is capable of running on multiple GPU’s and batching images really helps to speed things up. Using checkpoints will allow you to resume training from your last checkpoint if interrupted. This can be very useful, especially when training cycle GANs as they take a bit longer than pix2pix GANs. Lastly, the models are designed to be trained on either Nvidia GPUs or a CPU but we have not tried training on CPUs.

