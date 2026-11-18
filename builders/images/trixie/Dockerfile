FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    GIT_TERMINAL_PROMPT=0 \
    BUILDER_JOBS=2 \
    HYPR_BUILDER_JOBS=2 \
    XDG_RUNTIME_DIR=/tmp/builders-runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git shellcheck sudo util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 1000 --create-home --shell /bin/bash builder \
    && printf 'builder ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder \
    && install -d -o builder -g builder -m 0700 /tmp/builders-runtime \
    && install -d -o builder -g builder /home/builder/.local/share/builders-stage-cache

WORKDIR /workspace
COPY gcc-builder ./gcc-builder
COPY hypr-builder ./hypr-builder
COPY .github/images/trixie/*.sh /usr/local/lib/builders-tests/

USER builder
ENV USER=builder
CMD ["bash", "/usr/local/lib/builders-tests/test.sh"]
