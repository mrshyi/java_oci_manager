# syntax=docker/dockerfile:1.7

ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241

FROM ${DEBIAN_IMAGE} AS downloader

ARG TARGETARCH
ARG RBOT_VERSION=10.5.0
ARG RBOT_SHA256_AMD64=7b7a99cdf25f73c5d07335a37da326014e52910b55e4501e997e9cade4d41bf2
ARG RBOT_SHA256_ARM64=098408934188bfff680563ac9ec41aab61f613c7c00b32829c45e9ec8780e9fc

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /out

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        asset="gz_client_bot_x86_compatible.tar.gz"; \
        expected_sha256="${RBOT_SHA256_AMD64}" \
        ;; \
      arm64) \
        asset="gz_client_bot_aarch.tar.gz"; \
        expected_sha256="${RBOT_SHA256_ARM64}" \
        ;; \
      *) \
        echo "Unsupported target architecture: ${TARGETARCH}" >&2; \
        exit 1 \
        ;; \
    esac; \
    curl --fail --location --retry 5 --retry-all-errors \
      --output /tmp/rbot.tar.gz \
      "https://github.com/semicons/java_oci_manage/releases/download/v${RBOT_VERSION}/${asset}"; \
    echo "${expected_sha256}  /tmp/rbot.tar.gz" | sha256sum --check --strict; \
    tar --extract --gzip --file /tmp/rbot.tar.gz --directory /out \
      --no-same-owner --no-same-permissions; \
    test -s /out/r_client; \
    test -s /out/client_config; \
    chmod 0755 /out/r_client; \
    chmod 0640 /out/client_config; \
    rm /tmp/rbot.tar.gz

FROM ${DEBIAN_IMAGE} AS runtime

ARG RBOT_VERSION=10.5.0
ARG BUILD_DATE
ARG VCS_REF
ARG REPOSITORY_URL

LABEL org.opencontainers.image.title="R-Bot client" \
      org.opencontainers.image.description="Containerized semicons/java_oci_manage native client" \
      org.opencontainers.image.source="${REPOSITORY_URL}" \
      org.opencontainers.image.url="${REPOSITORY_URL}" \
      org.opencontainers.image.documentation="https://github.com/semicons/java_oci_manage" \
      org.opencontainers.image.version="${RBOT_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      ca-certificates \
      curl \
      tini \
      tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 rbot \
    && useradd --uid 10001 --gid 10001 --no-create-home \
      --home-dir /var/lib/rbot --shell /usr/sbin/nologin rbot \
    && install --directory --owner rbot --group rbot --mode 0750 \
      /var/lib/rbot /run/rbot-secrets

WORKDIR /opt/rbot

COPY --from=downloader --chown=root:root --chmod=0755 /out/r_client /opt/rbot/r_client
COPY --from=downloader --chown=root:rbot --chmod=0640 /out/client_config /opt/rbot/client_config.default
COPY --chown=root:root --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV RBOT_PORT=9527 \
    RBOT_DATA_DIR=/var/lib/rbot \
    HOME=/var/lib/rbot \
    TZ=Asia/Singapore

USER 10001:10001

EXPOSE 9527
VOLUME ["/var/lib/rbot"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl --fail --silent --show-error --insecure \
    "https://127.0.0.1:${RBOT_PORT}/radiance-bot-client/roc/api/client/health" \
    >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
