FROM alpine:3.21

RUN apk add postgresql16 jq

RUN wget https://releases.hashicorp.com/vault/1.18.3/vault_1.18.3_linux_amd64.zip -O vault.zip && \
  unzip vault.zip vault && \
  mv vault /usr/local/bin/ && \
  rm vault.zip

RUN wget https://github.com/Pondidum/nomad-listener/releases/download/56102de/nomad-listener -O nomad-listener && \
  chmod +x nomad-listener && \
  mv nomad-listener /usr/local/bin

WORKDIR /operator

COPY handlers/ handlers/
COPY create-db.sh ./


ENTRYPOINT [ "nomad-listener" ]
