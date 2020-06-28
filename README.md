# Dockerowy kontener z serverem wwww ŁuczniczQA

Zadanie:
    
    * Dockerowy Server www z logiem ŁuczniczQA i textem o jak najmniejszym rozmiarze

Rozwiązanie:
    
    * Serwer napisany w asemblrze z wkompilowanym kodem źródłowym strony
    * Tworzenie bazowego kontera dockerowego
        
## Przygotowanie serwera www

W celu uzyskania jak najmniejszego serwera należy się cofnąć kilka lat wstecz - i odświeżyć już zapomniane technologie z czasów technikum :)

![Serwer w asemblerze](data/czlowiek-z-kamienia.jpg)

```
SECTION .data
; our response string
response db 'HTTP/1.1 200 OK', 0Dh, 0Ah, 'Content-Type: text/html', 0Dh, 0Ah, 'Content-Length: 62369', 0Dh, 0Ah, 0Dh, 0Ah, '<html><head>..

..
_write:
    mov     edx, 62451          ; move 62451 dec into edx (length in bytes to write)
    mov     ecx, response       ; move address of our response variable into ecx
    mov     ebx, esi            ; move file descriptor into ebx (accepted socket id)
    mov     eax, 4              ; invoke SYS_WRITE (kernel opcode 4)
    int     80h                 ; call the kernel
..
```

* Kompilacja

```shell script
# Compilation
$ nasm -f elf httpd.asm

# Link with (64 bit systems require elf_i386 option): 
$ ld -m elf_i386 httpd.o -o httpd
# Run with exposure on port 9001 
$ ./httpd 
```

## Tworzenie bazowego imagea

[Docker tworzenie bazowego kontenera](https://docs.docker.com/develop/develop-images/baseimages/)

* Tworzenie image'a korzystając z wykorzystaniem tar'a
    * zalety mały nakład pracy
    * wady wymagane środowisko z narzędziami do kompilacji serwera
    
```shell script
$ echo httpd > manifest.txt
$ tar cv --files-from manifest.txt | docker import - httpd
```

Zapisanie konteneru 
```shell script
$ docker save httpd -o httpd.tar
```

Wczytanie konteneru z pliku
```shell script
$ docker load -i httpd.tar
```
* Problem po przeinstalowaniu systemu
    * należy stwarzać środowisko od podstaw

## Konetenery mają warstwy
![Dockery maja warstwy](data/shrek.jpg)
* [multi-stage build](https://docs.docker.com/develop/develop-images/multistage-build/)
* Tworzenie bazowego kontenera z wykorzystaniem **scratch**
  * wymaga statycznie podlinkowanych bibliotek

Dockerfile do kompilacji i debugowania
```dockerfile
ARG UBUNTUVERSION=18.04

FROM ubuntu:$UBUNTUVERSION

ENV TZ="Europe/Warsaw"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Install packages necessary for installing NASM
RUN apt-get update
RUN apt-get install -y \
       nasm \
       binutils \
       xxd

# Run shell if container is started
CMD ["/bin/bash"]
```

Budowanie kontenera do kompilacji

```shell script
#export i=18.04;docker build --build-arg UBUNTUVERSION=${i} ubuntu-nasm -t luczniczqa/nasm:ubuntu-${i}
docker build ubuntu-nasm -t luczniczqa/nasm:ubuntu-${i}
```

Przykładowe uruchomienia docker'a do budowania/debugowania
```shell script
docker run --rm -it -p8000:8000 -v $PWD:/sources/ cda77692d511 bash
```

Tworzenie bazowego docker'a z serwerem httpd wykorzystując warstwy do budowania
```dockerfile
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
```

Tworzenie kontenera z serwerem http
```shell script
docker build --build-arg SOURCE=luczniczqa/nasm:ubuntu-18.04 . -t luczniczqa/httpd:ubuntu-18.04
```

### docker run example

```shell script
$ docker run -d --name httpd -p 9001:9001 httpd ./httpd
```


### Rozmiar ~~nie~~ jest najważniejszy

* most size of docker image is used to store the ŁuczniczQA photo:)

```shell script
$ du -sh luczniczqa.svg 
64K     luczniczqa.svg
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
<none>              <none>              078436adadc9        10 seconds ago       113MB
luczniczqa/nasm     ubuntu-20.04        a1647dbd5851        25 seconds ago       113MB
luczniczqa/httpd    ubuntu-18.04        7ca0af82cbe5        50 seconds ago       63.5kB
luczniczqa/httpd    ubuntu-20.04        7ca0af82cbe5        50 seconds ago       63.5kB
<none>              <none>              70561f84d7a5        50 seconds ago       112MB
luczniczqa/nasm     ubuntu-18.04        c666b2a72495        About a minute ago   112MB
ubuntu              20.04               74435f89ab78        11 days ago          73.9MB
ubuntu              18.04               8e4ce0a6ce69        11 days ago          64.2MB
```

## Notes:
### Size of docker container created based on tutorial increased to 71KB

add option **-z noseparate-code**

https://sourceware.org/git/gitweb.cgi?p=binutils-gdb.git;a=blob_plain;f=ld/NEWS;hb=refs/tags/binutils-2_34

```
Changes in 2.31:
Add a configure option --enable-separate-code to decide whether
  -z separate-code should be enabled in ELF linker by default.  Default
  to yes for Linux/x86 targets.  Note that -z separate-code can increase
  disk and memory size.
```

### Żródłą:
