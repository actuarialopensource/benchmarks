docker build . -t lol
docker run lol # no gpu
docker run --gpus all lol

act -j build -s "CODECOV_TOKEN=your-codecov-token-abc555-5555"