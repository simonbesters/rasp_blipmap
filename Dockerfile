# sudo docker build -t netherlands .
FROM fedora:25

ENV BASEDIR=/root/rasp/

RUN mkdir $BASEDIR

# required packages
RUN dnf update -y && dnf install -y \
  netcdf-fortran \
  libpng15 \
  iproute-tc \
  tcp_wrappers-libs \
  sendmail \
  procmail \
  psmisc \
  procps-ng \
  mailx \
  findutils \
  ImageMagick \
  perl-CPAN \
  ncl \
  netcdf \
  libpng \
  libjpeg-turbo \
  which \
  patch \
  vim \
  less \
  bzip2
  
# configure CPAN and install required modules
RUN (echo y;echo o conf prerequisites_policy follow;echo o conf commit) | cpan \
  && cpan install Proc/Background.pm

# fix dependencies
RUN ln -s libnetcdff.so.6 /lib64/libnetcdff.so.5 \
  && ln -s libnetcdf.so.11 /lib64/libnetcdf.so.7

WORKDIR /root/

#
# Download and unpack necessary data
#

# Download and unpack static geographical data directory
# Assuming you already downloaded this file
# ADD https://www.dropbox.com/sh/n25p0nz6bgvjzlb/AABfOgE6bbOVBJjZgYWoHyfma/geog.tar.gz $BASEDIR
COPY geog.tar.gz $BASEDIR
RUN cd $BASEDIR \
  && tar xf geog.tar.gz \
  && rm geog.tar.gz
RUN ls $BASEDIR

# Download and unpack raspGM
# Assuming you already downloaded this file
# ADD https://github.com/wargoth/rasp-gm/archive/rasp-gm-stable.tar.gz $BASEDIR
COPY rasp-gm-stable.tar.gz $BASEDIR
RUN cd $BASEDIR \
  && tar xf rasp-gm-stable.tar.gz --strip-components=1 \
  && rm rasp-gm-stable.tar.gz \
  && rm -rf $BASEDIR/PANOCHE
RUN ls $BASEDIR

# Download and unpack detailed coastlines and lakes directory
# Assuming you already downloaded this file
# ADD https://www.dropbox.com/sh/n25p0nz6bgvjzlb/AACgTIBZNHLOAW7PxYslVDs2a/rangs.tgz $BASEDIR
COPY rangs.tgz $BASEDIR
RUN cd $BASEDIR \
  && tar xf rangs.tgz \
  && rm rangs.tgz
RUN ls $BASEDIR

#
# Set environment for interactive container shells
#
RUN echo export BASEDIR=$BASEDIR >> /etc/bashrc \
  && echo export PATH+=:\$BASEDIR/bin >> /etc/bashrc

# cleanup 
RUN yum clean all

# Download and unpack NETHERLANDS directory
# Assuming you already downloaded this file
COPY NETHERLANDS.tar.gz $BASEDIR
RUN cd $BASEDIR \
  && tar xf NETHERLANDS.tar.gz \
  && rm NETHERLANDS.tar.gz
RUN ls $BASEDIR
RUN ls $BASEDIR/NETHERLANDS

# Change download links to new format
# Change in ftp2u_subregion.pl "\&dir=\%2Fgfs.$curdate$runTime" into "\&dir=\%2Fgfs.$curdate/$runTime" was already applied
RUN sed -i 's/gfs.%04d%02d%02d%02d/gfs.%04d%02d%02d\/%02d/' $BASEDIR/bin/GM-master.pl

#COPY $BASEDIR/NETHERLANDS/wrfsi.nl $BASEDIR/NETHERLANDS/rasp.run.parameters.NETHERLANDS $BASEDIR/NETHERLANDS/
RUN cp -a $BASEDIR/NETHERLANDS/rasp.region_data.ncl $BASEDIR/GM/
RUN cp -a $BASEDIR/NETHERLANDS/rasp.site.runenvironment $BASEDIR/
RUN cp -a $BASEDIR/NETHERLANDS/calc_funcs.ncl $BASEDIR/GM/
RUN cp -a $BASEDIR/NETHERLANDS/plot_funcs.ncl $BASEDIR/GM/
RUN cp -a $BASEDIR/NETHERLANDS/rasp.site_load.pressure-level.ncl $BASEDIR/GM/
RUN cp -a $BASEDIR/NETHERLANDS/rasp.site_load.xbl.ncl $BASEDIR/GM/
RUN cp -a $BASEDIR/NETHERLANDS/pfd.rgb $BASEDIR/GM/
RUN cp -a $BASEDIR/NETHERLANDS/press26.rgb $BASEDIR/GM/
RUN cp -a $BASEDIR/region.TEMPLATE/. $BASEDIR/NETHERLANDS/
RUN ls $BASEDIR/NETHERLANDS

ENV PATH="${BASEDIR}/bin:${PATH}"

# initialize
RUN cd $BASEDIR/NETHERLANDS/ \
  && wrfsi2wps.pl \
  && wps2input.pl \
  && geogrid.exe

RUN rm -rf $BASEDIR/geog

WORKDIR /root/rasp/

VOLUME ["/root/rasp/NETHERLANDS/OUT/", "/root/rasp/NETHERLANDS/LOG/"]

#CMD ["bash"]
#CMD ["runGM", "NETHERLANDS"]
