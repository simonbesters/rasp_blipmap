#Callback after finishing blipmaps.nl run

After running a RASP run, you may want to process the outcome. This docker image is there to do that. We use it for:
- uploading the images to the website
- zipping the files for less bandwidth
- setting the rights of the files (so that the website can access them)
- removing of fields in the wrfout files
- removing the images after the above

The docker image will (via de docker-compse) look at the /tmp/OUT directory. Every 10 seconds it will determine if there is a directory with the file GM.printout there. If that directory is present, it will assume it is a directory with images and run all the scripts that are necessary.

It will expect a directory with a name like /tmp/OUT/20210121/1745/NETHERLANDS/0 and parses this format (see script parse_directory.sh).

It will then run each script that is named in the variable CALLBACK_<REGION>. In the example above, this is NETHERLANDS. Separate the scripts with a space.

E.g. in my .env file I have the following:

targetUrl="rasp@host:/home/rasp/domain/blipmaps.nl/images/"
CALLBACK_NETHERLANDS=deleteWrfFiles.sh convertImages.sh upload_images.sh backup_images.sh delete_images.sh
CALLBACK_NL1KM=convertImages.sh convertWrfoutForXbl.sh upload_images.sh backup_images.sh delete_images.sh

##own scripts
If you want to add your own script, do not forget to include it in the Dockerfile AND the .env file

If you want to add a region, do not forget to include it in both the .env file AND the docker-compose.yml file.

## Run the docker-compose
Do the following from within the callback directory:

Build the image:
```
docker compose -f docker-compose.yml build callback
```

Run the image:
```
docker compose -f docker-compose.yml up
```

Run the image as daemon, it will startup after a reboot:
```
docker compose -f docker-compose.yml up -d
```
