FROM ubuntu:22.04
RUN apt-get -y update && apt-get -y install gcc g++ git rsync curl python3 python3-numpy python-is-python3 \
  && rm -rf /var/lib/apt/lists/*

COPY build.sh /
RUN /build.sh

