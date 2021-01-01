# This image is supposed to run continuously
#   docker-compose -f docker-compose.yml build callback
#   docker-compose -f docker-compose.yml run callback

FROM debian:stable

#Basic environment
ENV BASEDIR=/
ENV TZ=Europe/Amsterdam

# required packages
RUN apt-get update && apt-get install -y locales 
  findutils \
  ImageMagick \
  ncl \
  netcdf \
  libpng \
  libjpeg-turbo \
  less \
  bzip2 \
  pigz \
  openssh-clients

RUN rm -rf /var/lib/apt/lists/* && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN mkdir /raspbin
WORKDIR /raspbin

VOLUME ["/data"]

COPY *.sh ${BASEDIR}/raspbin

#Add ssh keys to upload to $targetUrl location
ARG ssh_prv_key
ARG ssh_pub_key
ARG ssh_known_hosts
RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh
RUN ln -s /run/secrets/host_ssh_known_hosts ~/.ssh/known_hosts

# The runRasp.sh script is called with 1 argument: The area it is running
ENTRYPOINT ["callback.sh"]
CMD ["NETHERLANDS"]






# create standard linux image

# install required apps (netcdf, image stuff, ssh, ... )

# copy scripts

# create script that will poll directory every 10s.

# make it run all scripts from .env