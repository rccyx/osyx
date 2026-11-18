# Container 

```sh
docker build -t builders-trixie -f .github/images/trixie/Dockerfile .
docker run --rm builders-trixie bash /usr/local/lib/builders-tests/lint.sh
docker run --rm builders-trixie
```
To reuse completed build stages locally:

```sh
docker volume create builders-stage-cache
docker run --rm \
  --mount type=volume,source=builders-stage-cache,target=/home/builder/.local/share/builders-stage-cache \
  builders-trixie
```
