FROM --platform=$BUILDPLATFORM golang:1.19.2

COPY . /clusterpedia

# RUN rm -rf /clusterpedia/.git
# RUN rm -rf /clusterpedia/test

ENV CLUSTERPEDIA_REPO="/clusterpedia"

RUN cp /clusterpedia/hack/builder.sh /
