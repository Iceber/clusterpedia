#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

set +e; REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null);set -e
if [ -z $REPO_ROOT ]; then
    if [ -z $CLUSTERPEDIA_REPO ]; then
        echo "please set CLUSTERPEDIA_REPO=<dir>"
        exit
    fi
    REPO_ROOT=$(pwd)
else
    CLUSTERPEDIA_REPO=${CLUSTERPEDIA_REPO:-$REPO_ROOT}
fi

CLUSTERPEDIA_PACKAGE="github.com/clusterpedia-io/clusterpedia"
if [ $CLUSTERPEDIA_PACKAGE != "$(sed -n '1p' ${CLUSTERPEDIA_REPO}/go.mod | awk '{print $2}')" ]; then
    echo "CLUSTERPEDIA_REPO is invalid"
    exit
fi

OUTPUT_DIR=${OUTPUT_DIR:-$REPO_ROOT}

TMP_GOPATH=/tmp/clusterpedia
function cleanup() {
    rm -rf $TMP_GOPATH
}

TMP_CLUSTERPEDIA=$TMP_GOPATH/src/$CLUSTERPEDIA_PACKAGE
function copy_clusterpedia_repo() {
    mkdir -p $TMP_CLUSTERPEDIA && cd $TMP_CLUSTERPEDIA
    cp -rf $CLUSTERPEDIA_REPO/* .

    for file in $(ls staging/src/github.com/clusterpedia-io); do
        rm -rf vendor/github.com/clusterpedia-io/$file
    done

    cp -rf staging/src/github.com/clusterpedia-io/* $TMP_GOPATH/src/github.com/clusterpedia-io
    cp -rf vendor/* $TMP_GOPATH/src
    rm -rf go.mod go.sum vendor

    rm $TMP_GOPATH/src/modules.txt
}

GOOS=${GOOS:-$(go env GOOS)}
GOARCH=${GOARCH:-$(go env GOARCH)}

CC_FOR_TARGET=${CC_FOR_TARGET:-""}
CC=${CC:-""}
if [ "${GOOS}" == "linux" && "${GOOS}" != "$(go env GOHOSTARCH)"; then
    if [ "${GOARCH}" == "amd64" ]; then
        CC_FOR_TARGET=${CC_FOR_TARGET:-"gcc-x86-64-linux-gnu"}
        CC=${CC:-"x86-64-linux-gnu-gcc"}
    else
        CC_FOR_TARGET=${CC_FOR_TARGET:-"gcc-aarch64-linux-gnu"}
        CC=${CC:-"aarch64-linux-gnu-gcc"}
    fi
fi

function build_component() {
    local LDFLAGS=${BUILD_LDFLAGS:-""}
    if [ -f ${CLUSTERPEDIA_REPO}/ldflags.sh ]; then
        cd ${CLUSTERPEDIA_REPO} && source ./ldflags.sh
    fi

    cd $TMP_CLUSTERPEDIA
    #local cmd="${BUILD_ARGS} go build -ldflags "${LDFLAGS}" -o $OUTPUT_DIR/bin/$1 ./cmd/$1"
    #echo "build $1: \n $cmd"
    GO111MODULE=off CGO_ENABLED=1 GOPATH=$TMP_GOPATH CC_FOR_TARGET=$CC_FOR_TARGET CC=$CC go build -ldflags "${LDFLAGS}" -o $OUTPUT_DIR/bin/$1 ./cmd/$1
}

cleanup
trap cleanup EXIT

mkdir -p $TMP_GOPATH

case $1 in
    plugins)
        if [ -z $2 ]; then
            echo "please set plugin name"
            exit
        fi
        ;;
    *)
        copy_clusterpedia_repo
        build_component $1
        exit
        ;;
esac

PLUGIN_REPO=${PLUGIN_REPO:-$REPO_ROOT}
if [ $CLUSTERPEDIA_REPO == $PLUGIN_REPO ]; then
    echo "please set a diff repo path"
    exit 1
fi

PLUGIN_PACKAGE="$(sed -n '1p' go.mod | awk '{print $2}')"
TMP_PLUGIN=$TMP_GOPATH/src/$PLUGIN_PACKAGE
function copy_plugin_repo() {
    mkdir -p $TMP_PLUGIN && cd $TMP_PLUGIN
    cp -r $PLUGIN_REPO/* .

    [ -f go.mod ] && [ ! -d ./vendor ] && GO111MODULE=on go mod vendor

    rm -rf vendor/$CLUSTERPEDIA_PACKAGE
    for file in $CLUSTERPEDIA_REPO/staging/src/github.com/clusterpedia-io/*; do
        if [ -d file ]; then
            rm -rf vendor/github.com/clusterpedia-io/$file
        fi
    done

    cp -rf vendor/* $TMP_GOPATH/src
    rm -rf go.mod go.sum vendor

    rm $TMP_GOPATH/src/modules.txt
}

function build_plugin() {
    local LDFLAGS=${BUILD_LDFLAGS:-""}
    if [ -f ${PLUGIN_REPO}/ldflags.sh ]; then
        cd ${PLUGIN_REPO} && source ./ldflags.sh
    fi

    cd $TMP_PLUGIN
    ${BUILD_ARGS} go build -ldflags "$LDFLAGS" -buildmode=plugin -o $OUTPUT_DIR/plugins/$1
}

copy_plugin_repo

copy_clusterpedia_repo

build_plugin $2
