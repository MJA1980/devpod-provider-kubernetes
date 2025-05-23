#!/usr/bin/env bash
set -e

export GO111MODULE=on
export GOFLAGS=-mod=vendor

PROVIDER_ROOT=$(git rev-parse --show-toplevel)
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
DATE=$(date "+%Y-%m-%d")
BUILD_PLATFORM=$(uname -a | awk '{print tolower($1);}')

echo "Current working directory is $(pwd)"
echo "PATH is $PATH"
echo "GOPATH is $GOPATH"

if [[ "$(pwd)" != "${PROVIDER_ROOT}" ]]; then
  echo "you are not in the root of the repo" 1>&2
  echo "please cd to ${PROVIDER_ROOT} before running this script" 1>&2
  exit 1
fi

GO_BUILD_CMD="go build"
GO_BUILD_LDFLAGS="-s -w"

BUILD_VERSION="prod"
for arg in "$@"; do
    if [ "$arg" == "--dev" ]; then
        BUILD_VERSION="dev"
        break
    fi
done

echo "Building version: ${BUILD_VERSION}"

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
    GITHUB_REPOSITORY="loft-sh/devpod-provider-kubernetes"
fi

if [[ -z "${PROVIDER_BUILD_PLATFORMS}" ]]; then
    PROVIDER_BUILD_PLATFORMS="linux windows darwin"
fi

if [[ -z "${PROVIDER_BUILD_ARCHS}" ]]; then
    PROVIDER_BUILD_ARCHS="amd64 arm64"
fi

# Create the release directory
mkdir -p "${PROVIDER_ROOT}/release"

for OS in ${PROVIDER_BUILD_PLATFORMS[@]}; do
  for ARCH in ${PROVIDER_BUILD_ARCHS[@]}; do
    NAME="devpod-provider-kubernetes-${OS}-${ARCH}"
    if [[ "${OS}" == "windows" ]]; then
      NAME="${NAME}.exe"
    fi

    # darwin 386 is deprecated and shouldn't be used anymore
    if [[ "${ARCH}" == "386" && "${OS}" == "darwin" ]]; then
        echo "Building for ${OS}/${ARCH} not supported."
        continue
    fi

    # arm64 build is only supported for darwin
    if [[ "${ARCH}" == "arm64" && "${OS}" == "windows" ]]; then
        echo "Building for ${OS}/${ARCH} not supported."
        continue
    fi

    echo "Building for ${OS}/${ARCH}"
    GOARCH=${ARCH} GOOS=${OS} ${GO_BUILD_CMD} -ldflags "${GO_BUILD_LDFLAGS}"\
      -o "${PROVIDER_ROOT}/release/${NAME}" main.go
    shasum -a 256 "${PROVIDER_ROOT}/release/${NAME}" | cut -d ' ' -f 1 > "${PROVIDER_ROOT}/release/${NAME}".sha256
  done
done

go run -mod vendor "${PROVIDER_ROOT}/hack/provider/main.go" ${RELEASE_VERSION} ${BUILD_VERSION} ${PROVIDER_ROOT} ${GITHUB_REPOSITORY} > "${PROVIDER_ROOT}/release/provider.yaml"
