ARG UBUNTUVERSION=18.04

FROM ubuntu:$UBUNTUVERSION
LABEL author="Dariusz Duelba"

ENV TZ="Europe/Warsaw"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Install packages necessary for installing NASM
RUN apt-get update
RUN apt-get install -y \
       nasm \
       binutils

# Run shell if container is started
CMD ["/bin/bash"]