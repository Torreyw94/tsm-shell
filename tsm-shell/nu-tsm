FROM ubuntu:22.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  bash curl git nano vim jq python3 python3-pip \
  iputils-ping dnsutils net-tools procps unzip zip \
  && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
