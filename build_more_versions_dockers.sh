#!/bin/bash

for i in 18.04 20.04;do
  echo $i
  docker build --build-arg UBUNTUVERSION=${i} ubuntu-nasm -t luczniczqa/nasm:ubuntu-${i}
  docker build --build-arg SOURCE=luczniczqa/nasm:ubuntu-${i} . -t luczniczqa/httpd:ubuntu-${i}
done