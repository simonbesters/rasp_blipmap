# This image is supposed to run continuously
#   docker compose -f docker-compose.yml build callback
#   docker compose -f docker-compose.yml run callback

FROM debian:stable

#Basic environment
ENV BASEDIR=/
ENV TZ=Europe/Amsterdam

# required packages
RUN apt-get update && apt-get install -y locales \
  findutils \
  imagemagick \
  ncl-ncarg \
  netcdf-bin \
  libpng16-16 \
  libjpeg-turbo-progs \
  less \
  bzip2 \
  pigz \
  openssh-client \
  rsync \
  nco

RUN rm -rf /var/lib/apt/lists/* && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

ENV PATH="${BASEDIR}/raspbin:${PATH}"
RUN export BASEDIR=${BASEDIR}
RUN export PATH=${PATH}

RUN mkdir /raspbin
WORKDIR /raspbin

VOLUME ["/data"]

COPY callback.sh convertWrfoutForXbl.sh delete_images.sh deleteWrfFiles.sh doNothing.sh parse_directory.sh upload_images.sh ${BASEDIR}/raspbin/

#Add ssh keys to upload to $targetUrl location
ARG ssh_prv_key
ARG ssh_pub_key
ARG ssh_known_hosts
RUN mkdir -p ~/.ssh && \
    chmod 0700 ~/.ssh && \
    ln -s /run/secrets/host_ssh_known_hosts ~/.ssh/known_hosts

ENTRYPOINT ["callback.sh"]
CMD ["/data"]
