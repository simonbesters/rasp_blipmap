# Welcome to running RASP images 

## Create the images
You can vary later, but first set yourself up with our example by running:

- docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build base
- docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build wrf_build
- docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build wrf_prod
- docker compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS build rasp

and run the image with region NL4KMGFS by:
- creating output directories:
  - mkdir -p /tmp/results/LOG && mkdir -p /tmp/results/OUT
- docker-compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS rasp

or you can enter the image by:
- docker-compose --env-file ./docker_env --env-file ./docker_env_NL4KMGFS rasp /bin/bash
- run bin/runRasp.sh from the cmd line

The following regions are available in our image:
- NL4KMGFS
- NL4KMICON
- NL1KMGFS
- NL1KMICON

Replace the right env file in the above commands. 
