docker build . -t lol
docker run lol # no gpu
docker run --gpus all lol