# #!/usr/bin/env bash

# # This script aims at helping create a PR to update the manifests of the
# # knative.
# # This script:
# # 1. Checks out a new branch
# # 2. Download files into the correct places
# # 3. Commits the changes
# #
# # Afterwards the developers can submit the PR to the kubeflow/manifests
# # repo, based on that local branch
# # It must be executed directly from its directory

# # strict mode http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euxo pipefail
IFS=$'\n\t'

COMMIT="1.22.0"
CURRENT_VERSION="1-21" 
NEW_VERSION="1-22" # Must be a release

SRC_DIR=${SRC_DIR:=/tmp/istio} # Must be a release
BRANCH=${BRANCH:=istio-${COMMIT?}}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MANIFESTS_DIR=$(dirname $SCRIPT_DIR)

ISTIO_OLD=$MANIFESTS_DIR/common/istio-${CURRENT_VERSION}
ISTIO_NEW=$MANIFESTS_DIR/common/istio-${NEW_VERSION}

if [ ! -d "$ISTIO_NEW" ]; then
cp -a $ISTIO_OLD $ISTIO_NEW
fi 

echo "Creating branch: ${BRANCH}"

if [ -n "$(git status --porcelain)" ]; then
  echo "WARNING: You have uncommitted changes"
fi
if [ `git branch --list $BRANCH` ]
then
   echo "WARNING: Branch $BRANCH already exists."
fi

# Create the branch in the manifests repository
if ! git show-ref --verify --quiet refs/heads/$BRANCH; then
    git checkout -b $BRANCH
else
    echo "Branch $BRANCH already exists."
fi
echo "Checking out in $SRC_DIR to $COMMIT..."

# Checkout the istio repository
if [ ! -d "$SRC_DIR" ]; then
mkdir -p $SRC_DIR
fi
cd $SRC_DIR
if [ ! -d "istio-${COMMIT}-linux-amd64.tar.gz" ]; then
    wget "https://github.com/istio/istio/releases/download/${COMMIT}/istio-${COMMIT}-linux-amd64.tar.gz"
    tar xvfz istio-${COMMIT}-linux-amd64.tar.gz
fi

sudo mv istio-${COMMIT}/bin/istioctl /usr/local/bin/istioctl

cd $ISTIO_NEW
istioctl profile dump default > profile.yaml

# cd $ISTIO_NEW
# export PATH="$MANIFESTS_DIR/scripts:$PATH"
istioctl manifest generate --cluster-specific -f profile.yaml -f profile-overlay.yaml > dump.yaml
./split-istio-packages -f dump.yaml
mv $ISTIO_NEW/crd.yaml $ISTIO_NEW/istio-crds/base
mv $ISTIO_NEW/install.yaml $ISTIO_NEW/istio-install/base
mv $ISTIO_NEW/cluster-local-gateway.yaml $ISTIO_NEW/cluster-local-gateway/base
rm dump.yaml

if [ -n "$(git status --porcelain)" ]; then
  echo "WARNING: You have uncommitted changes"
fi

Updating README.md to sync with Istio upgraded version
echo "Updating README..."
SRC_TXT="\[.*\](https://github.com/istio/istio/releases/tag/.*)"
DST_TXT="\[$COMMIT\](https://github.com/istio/istio/releases/tag/$COMMIT)"

sed -i "s|$SRC_TXT|$DST_TXT|g" "${MANIFESTS_DIR}"/README.md

#Syncing updated directory's name with other files
find "$MANIFESTS_DIR" -type f -exec sed -i "s/istio-${CURRENT_VERSION}/istio-${NEW_VERSION}/g" {} +

echo "Committing the changes..."
cd "$MANIFESTS_DIR"
rm -rf $ISTIO_OLD
git add .
git commit -s -m "Updated istio to v.${COMMIT}"