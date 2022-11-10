#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

function usage() {
    cat <<EOF
ENV:
    REF: if you want to push code to api repo in one branch the format is refs/heads/<branch_name>,
         if you want to push tag to api repo the format is is refs/tags/<tag_name>
    TAGNAME: this will be synced to the api repo as tag name
    REFTYPE: the current operation is tag or sync code. if it is undefined, it defaults to branch
        eg. REFTYPE=tag  or  REFTYPE=branch
    BRANCH_NAME: current branch name
        eg. BRANCH_NAME=main
    GH_TOKEN: github token for api repo auth.
EOF
}

API_ROOT="staging/src/github.com/clusterpedia-io/api"
if [ ! -d $API_ROOT ];then
    echo "can not find API_ROOT in the path, please check in the clusterpedia root path"
    exit 1
fi

set +e; RAW=$(git branch -r --contains $REF 2>/dev/null);set -e
if [ -z $RAW ]; then
    echo "the current directory is not in the clusterpedia path"
    usege
    exit 1
fi

BRANCH_NAME=${RAW/origin\/}
if [ -z $BRANCH_NAME ]; then
    echo "can not get current branch"
    usage
    exit 1
fi

if [ -z $GH_TOKEN ]; then
    echo "the github token is not in the env, please check GH_TOKEN"
    usage
    exit 1
fi

if [ $REFTYPE=="tag" ]; then
    if [ -z $TAGNAME ]; then
        echo "tagname is required when tag"
        usage
        exit 1
    fi
fi

API_REPO="https://$GH_TOKEN@github.com/Iceber/api.git"

TAG_MESSAGE=$(git tag -l --format="%(contents)" $TAGNAME)

install_filter_repo(){
    python3 -m pip install --user git-filter-repo
}

# check tag, if exist, delete it
check_tag(){
    git tag -d $TAGNAME
    if [ -n "$(git ls-remote --tags origin -l $TAGNAME)" ]; then
        echo "tag already exist, delete it before retag"
        git push -d origin $TAGNAME
        git tag -d $TAGNAME
    fi
}

sync_api(){
  if [ $REFTYPE == "tag" ]; then
      git filter-repo --subdirectory-filter $API_ROOT --force
      git remote add origin $API_REPO
      check_tag
      git tag $TAGNAME -a -m $TAG_MESSAGE
      git push origin $TAGNAME
      echo "push tag success~"
    else
      git filter-repo --subdirectory-filter $API_ROOT --force
      git remote add origin $API_REPO
      git push origin $BRANCH_NAME
      echo "sync code success~"
  fi
}

install_filter_repo

sync_api
