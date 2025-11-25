#!/bin/bash
set -ex

VERSION="$1"
if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=go${VERSION}
fi

FULLNAME=go-${VERSION}.tar.xz
OUTPUT=/root/${FULLNAME}
S3OUTPUT=""
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

URL="https://go.googlesource.com/go"
DIR="${BRANCH}/go"
git clone --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

# determine build revision
REVISION="golang-$(git ls-remote "${URL}" "refs/heads/${BRANCH}" | cut -f 1)"
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi


pushd "${DIR}/src"
./make.bash
popd

pushd "${DIR}"
rm -rf \
    .git \
    .gitattributes \
    .github \
    pkg/bootstrap \
    pkg/linux_amd64/cmd \
    pkg/obj
popd

export GOROOT="${PWD}/${DIR}"
export GOCACHE="${GOROOT}/cache"

list=(
    "linux/amd64"
    "linux/arm64"
)

for i in "${list[@]}"; do
    echo $i | while IFS=/ read -r goos goarch;
    do
        echo "Populating build cache for ${goos}/${goarch}";
        export GOOS=${goos}
        export GOARCH=${goarch}
        $GOROOT/bin/go build std
    done
done

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./go,./go-${VERSION}/," -C "${BRANCH}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
