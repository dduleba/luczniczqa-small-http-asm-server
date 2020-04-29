# Small http server with ŁuczniczQA image and text

## sources

https://asmtutor.com/

## server compilation

```shell script
# Compilation
$ nasm -f elf httpd.asm
# Link with (64 bit systems require elf_i386 option): 
$ ld -m elf_i386 httpd.o -o httpd
# Run with exposure on port 9001 
$ ./httpd
```

## docker image creation

```shell script
$ echo httpd > manifest.txt
$ tar cv --files-from manifest.txt | docker import - httpd
```

## docker run example

```shell script
$ docker run -d --name httpd -p 9001:9001 httpd ./httpd
```

## docker image save

```shell script
$ docker save httpd -o httpd.tar
```

## docker image load

```shell script
$ docker load -i httpd.tar
```

## docker image size
* most size of docker image is used to store the ŁuczniczQA photo:)

```shell script
$ ls -l luczniczqa.svg
-rw-r--r-- 1 dduleba dduleba 62160 kwi 29 23:13 luczniczqa.svg

$ docker images httpd
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
httpd               latest              093acfaddbef        About a minute ago   63.4kB
```