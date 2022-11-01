ARG BUILDER_IMAGE
ARG BASE_IMAGE

FROM ${BUILDER_IMAGE} as builder
WORKDIR /clusterpedia

ARG BIN_NAME
ARG ON_PLUGINS
RUN make ${BIN_NAME}

FROM --platform=$BUILDPLATFORM ${BASE_IMAGE}

ARG ON_PLUGINS
RUN if [ "$ON_PLUGINS" = "true" ]; then apk add --no-cache gcompat; fi

ARG BIN_NAME
COPY --from=builder /clusterpedia/bin/${BIN_NAME} /usr/local/bin/${BIN_NAME}
