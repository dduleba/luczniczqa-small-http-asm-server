# Use a multi-stage build
ARG SOURCE=luczniczqa/nasm:ubuntu-18.04
FROM ${SOURCE} AS build

WORKDIR /src
COPY httpd.asm /src

# Compile and link our assembler code
RUN nasm -f elf httpd.asm \
  && ld -m elf_i386 -z noseparate-code httpd.o -o httpd

FROM scratch
COPY --from=build /src/httpd /
CMD ["/httpd"]