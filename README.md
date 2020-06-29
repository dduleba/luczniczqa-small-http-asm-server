![Logo ŁuczniczQA](data/luczniczqa.svg)
# Dockerowy kontener z serverem www ŁuczniczQA

    
Zadaniem konkursowym było postawienie na swoim komputerze kontenera Dockera 🐳 (https://www.docker.com/), a w środku niego strony www z logiem ŁuczniczQA. 😎

    Przy ocenie brane pod uwagę będą:
    ✅  kolejność zgłoszeń,
    ✅  estetyka strony internetowej,
    ✅  wielkość kontenera (oczywiście im mniejszy, tym lepszy).


Rozwiązanie:
    
    * Serwer w języku niskiego poziomu 
    * kod źródłowy strony wraz z grafiką częścią kodu
        * nie ma konieczności obsługi plików
    * Tworzenie bazowego kontera dockerowego
        
## Przygotowanie serwera www

W celu uzyskania jak najmniejszego serwera musiałem cofnąć się kilka lat wstecz 

* odświeżyć już zapomniane narzędzia (w moim przypadku z czasów technikum elektronicznego)
* **assembler** 
    * język niskiego poziomu który nie ma narzutu pod kątem wielkości
    * wiąże się to jednak z pewnymi trudnościami ale czego się nie robi dla **ŁuczniczQA**:)
 


![Serwer w asemblerze](data/czlowiek-z-kamienia.jpg)

Fragment kodu - tutaj nawet ja pokusiłem się o pozostawienie komentarzy
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

## Tworzenie bazowego image'a

Aby uzyskać jak najmniejszy obraz musimy ograniczyć jego zawartość
* w tym celu tworzymy obraz bazowy (nie korzystając z istniejących obrazów)
    * wymaga pliku binarnego ze statycznie podlinkowanymi bibliotekami
    * w przeciwieństwie do ogrów nasz obraz nie powinien posiadać wielu zbędnych warstw:)

![Dockery maja warstwy](data/shrek.jpg)
        
[Docker tworzenie bazowego kontenera](https://docs.docker.com/develop/develop-images/baseimages/)

* Tworzenie image'a korzystając z tar'a

```shell script
# Kompilacja
$ nasm -f elf httpd.asm
# Linkowanie 
$ ld -m elf_i386 httpd.o -o httpd
# Tworzenie Dockerowego obrazu
$ echo httpd > manifest.txt
$ tar cv --files-from manifest.txt | docker import - httpd
# Zapisanie konteneru do pliku
$ docker save httpd -o httpd.tar
# Wczytanie konteneru z pliku
$ docker load -i httpd.tar
```

Powyższe rozwiązanie ma pewne wady - przygotowanie binarki bazuje na systemie hosta
* W moim przypadku szybko się o tym przekonałem - szczęście testera :)
* Po zmianie systemu z ubuntu 18.04 na ubuntu 20.04 binarka przytyła z 63.5KB do 71KB
  * problem udało się rozwiązać przez dodatkowe opcje przy linkowaniu "**-z noseparate-code**"
  * aby jednak ustrzedz się podobnych problemów należało zoptymalizować samo budowanie i linkowanie 

## Optymalizacja

* [multi-stage build](https://docs.docker.com/develop/develop-images/multistage-build/) wraz z wykorzystaniem **from scratch**
 
Zatem nałatwiej do tego skorzystać z kolejnego docker'owego obrazu

```dockerfile
FROM ubuntu:18.04

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

Budowanie kontenera
```shell script
docker build ubuntu-nasm -t luczniczqa/nasm:ubuntu-18.04
```

Finalny Dockerfile 
* z **FROM luczniczqa/nasm:ubuntu-18.04 AS build** warstwą do budowania
* oraz **FROM scratch** w celu utworzenia bazowego obrazu
```dockerfile
# Use a multi-stage build
FROM luczniczqa/nasm:ubuntu-18.04 AS build

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
docker build . -t luczniczqa/httpd:ubuntu-18.04 -t luczniczqa/httpd:latest
```

Weryfikacja wielkości obrazu:
```shell script
# obraz do buodwania binarki
$ $ docker image history luczniczqa/nasm:ubuntu-18.04
  IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
  c666b2a72495        18 hours ago        /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B                  
  4c95c6c1ec3b        18 hours ago        /bin/sh -c apt-get install -y        nasm   …   18.6MB              
  6a6671e66f4a        18 hours ago        /bin/sh -c apt-get update                       28.8MB              
  b8a3ac7be637        18 hours ago        /bin/sh -c ln -snf /usr/share/zoneinfo/$TZ /…   47B                 
  d69fb480443c        18 hours ago        /bin/sh -c #(nop)  ENV TZ=Europe/Warsaw         0B                  
  90555d86f464        18 hours ago        /bin/sh -c #(nop)  LABEL author=Dariusz Duel…   0B                  
  8e4ce0a6ce69        12 days ago         /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B                  
  <missing>           12 days ago         /bin/sh -c mkdir -p /run/systemd && echo 'do…   7B                  
  <missing>           12 days ago         /bin/sh -c set -xe   && echo '#!/bin/sh' > /…   745B                
  <missing>           12 days ago         /bin/sh -c [ -z "$(apt-get indextargets)" ]     987kB               
  <missing>           12 days ago         /bin/sh -c #(nop) ADD file:1e8d02626176dc814…   63.2MB  

# docelowy obraz z binarką
$ docker image history luczniczqa/httpd
  IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
  7ca0af82cbe5        18 hours ago        /bin/sh -c #(nop)  CMD ["/httpd"]               0B                  
  fb01c7655ae1        18 hours ago        /bin/sh -c #(nop) COPY file:8462b2ff0924347f…   63.5kB
```

### docker run example

```shell script
$ docker run -d --name httpd -p 9001:9001 luczniczqa/httpd ./httpd
```

### Rozmiar ~~nie~~ jest najważniejszy

* most size of docker image is used to store the ŁuczniczQA photo:)

```shell script
$ ls -l data/luczniczqa.svg 
-rw-rw-r-- 1 ddl ddl 62160 cze  6 06:14 data/luczniczqa.svg
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
luczniczqa/httpd    ubuntu-18.04        7ca0af82cbe5        50 seconds ago       63.5kB
luczniczqa/nasm     ubuntu-18.04        c666b2a72495        About a minute ago   112MB
ubuntu              18.04               8e4ce0a6ce69        11 days ago          64.2MB
```

## QA

# Dołącz do nas

[![Dołącz do nas QA Automation Engineer](https://slack-imgs.com/?c=1&o1=ro&url=https%3A%2F%2Fhuuugegames.com%2Fassets%2Fthemes%2Fhuuuge%2Fpublic_html%2Fimg%2Fjoin-us-social.png)](https://huuugegames.com/careers/offer/?id=1779)


## Notes:
Przykładowe uruchomienia docker'a do budowania/debugowania
```shell script
docker run --rm -it -p9001:9001 -v $PWD:/sources/ luczniczqa/nasm:ubuntu-18.04 bash
```


add option **-z noseparate-code**

https://sourceware.org/git/gitweb.cgi?p=binutils-gdb.git;a=blob_plain;f=ld/NEWS;hb=refs/tags/binutils-2_34

```
Changes in 2.31:
Add a configure option --enable-separate-code to decide whether
  -z separate-code should be enabled in ELF linker by default.  Default
  to yes for Linux/x86 targets.  Note that -z separate-code can increase
  disk and memory size.
```

Narzędzie przydatne do inwestygacji zawartości binarki:
```shell script
$ xxd -c 30 httpd.big|head
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000 0200 0300 0100 0000 0090 0408 3400  .ELF........................4.
0000001e: 0000 c415 0100 0000 0000 3400 2000 0300 2800 0700 0600 0100 0000 0000 0000  ..........4. ...(.............
0000003c: 0080 0408 0080 0408 9400 0000 9400 0000 0400 0000 0010 0000 0100 0000 0010  ..............................
0000005a: 0000 0090 0408 0090 0408 b000 0000 b000 0000 0500 0000 0010 0000 0100 0000  ..............................
00000078: 0020 0000 00a0 0408 00a0 0408 e2f3 0000 e4f4 0000 0600 0000 0010 0000 0000  . ............................
00000096: 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000  ..............................
000000b4: 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000  ..............................
000000d2: 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000  ..............................
000000f0: 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000  ..............................
0000010e: 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000  ..............................
$ xxd -c 30 httpd|head
00000000: 7f45 4c46 0101 0100 0000 0000 0000 0000 0200 0300 0100 0000 8080 0408 3400  .ELF........................4.
0000001e: 0000 f4f6 0000 0000 0000 3400 2000 0200 2800 0700 0600 0100 0000 0000 0000  ..........4. ...(.............
0000003c: 0080 0408 0080 0408 3001 0000 3001 0000 0500 0000 0010 0000 0100 0000 3001  ........0...0...............0.
0000005a: 0000 3091 0408 3091 0408 e2f3 0000 e4f4 0000 0600 0000 0010 0000 0000 0000  ..0...0.......................
00000078: 0000 0000 0000 0000 31c0 31db 31ff 31f6 6a06 6a01 6a02 89e1 bb01 0000 00b8  ........1.1.1.1.j.j.j.........
00000096: 6600 0000 cd80 89c7 6a00 6668 2329 666a 0289 e16a 1051 5789 e1bb 0200 0000  f.......j.fh#)fj...j.QW.......
000000b4: b866 0000 00cd 806a 0157 89e1 bb04 0000 00b8 6600 0000 cd80 6a00 6a00 5789  .f.....j.W........f.....j.j.W.
000000d2: e1bb 0500 0000 b866 0000 00cd 8089 c6b8 0200 0000 cd80 83f8 0074 02eb ddba  .......f.................t....
000000f0: ff00 0000 b914 8505 0889 f3b8 0300 0000 cd80 b814 8505 08ba f3f3 0000 b930  .............................0
0000010e: 9104 0889 f3b8 0400 0000 cd80 89f3 b806 0000 00cd 80bb 0000 0000 b801 0000  ..............................
```