ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends bash curl jq iproute2 openssl tar unzip ca-certificates shellcheck bats && rm -rf /var/lib/apt/lists/*
WORKDIR /work
COPY . /work
CMD ["bash", "tests/validate_static.sh"]
