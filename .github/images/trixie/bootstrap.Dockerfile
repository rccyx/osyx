FROM debian:trixie

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates git python3 \
    && useradd --create-home --shell /bin/bash smoke \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
