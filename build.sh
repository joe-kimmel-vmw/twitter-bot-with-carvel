#!/bin/bash

set -eux

IMGVERSION=0.1.0
IMGREPOPATH="jkimmelvmware/toy-projects:artificialtweetener"
IMGREPOTAG=${IMGREPOPATH}-${IMGVERSION}
BUNDLEREPOPATH="jkimmelvmware/toy-projects:artificialtweetener-bundle"
BUNDLEREPOTAG=${BUNDLEREPOPATH}-${IMGVERSION}
PKGVERSION=1.0.0
PKGREPOPATH="jkimmelvmware/my-pkg-repo:packages"
PKGREPOTAG=${PKGREPOPATH}-${PKGVERSION}
REPOHOST="index.docker.io"
APPNAME="artificial-tweetener.github.com"

function docker_build_and_push() {
  docker build . -t ${IMGREPOTAG}
  # may need to `docker login --username="jkimmelvmware"` if access is denied
  docker push ${IMGREPOTAG}
}

function imgpkg_bundle_push() {
  cat > distribute/carvel/package-contents/config/values.yml <<- EOF
#@data/values
---
docker_image: ${IMGREPOTAG}
EOF

  kbld -f distribute/carvel/package-contents/config/ --imgpkg-lock-output distribute/carvel/package-contents/.imgpkg/images.yml

  imgpkg push -b ${REPOHOST}/${BUNDLEREPOTAG} -f distribute/carvel/package-contents/
}


function pkgrepo_push() {
  # TODO (should i do this with ytt instead?)
  cat > distribute/carvel/my-pkg-repo/packages/artificial-tweetener.github.com/${IMGVERSION}.yml <<- EOF
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: ${APPNAME}.${IMGVERSION}
spec:
  syncPeriod: 30m
  refName: ${APPNAME}
  version: ${IMGVERSION}
  releaseNotes: try not to be so jealous
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: ${REPOHOST}/${BUNDLEREPOTAG}
      template:
      - ytt:
          paths:
          - "config/"
      -kbld:
          paths:
          - "-"
          - ".imgpkg/images.yml"
      deploy:
      - kapp: {}
EOF

  kbld -f distribute/carvel/my-pkg-repo/packages/ --imgpkg-lock-output distribute/carvel/my-pkg-repo/.imgpkg/images.yml

  imgpkg push -b ${REPOHOST}/${PKGREPOTAG} -f distribute/carvel/my-pkg-repo
}

function consume_package_repository() {
  cat > distribute/carvel/consumer-repo.yml <<- EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: simple-package-repository
spec:
  syncPeriod: 30m
  fetch:
    imgpkgBundle:
      image: ${REPOHOST}/${PKGREPOTAG}
EOF

  cat > distribute/carvel/pkginstall.yml <<-EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: ${APPNAME}
spec:
  serviceAccountName: default-ns-sa
  packageRef:
    refName: ${APPNAME}
    versionSelection:
      constraints: ${IMGVERSION}
  values:
  - secretRef:
      name: opensesame
---
apiVersion: v1
kind: Secret
metadata:
  name: opensesame
stringData:
  twit-consumer-key: ${TWIT_CONSUMER_KEY}
  twit-consumer-secret: ${TWIT_CONSUMER_SECRET}
  twit-access-token: ${TWIT_ACCESS_TOKEN}
  twit-access-token-secret: ${TWIT_ACCESS_TOKEN_SECRET}
EOF

  # only have to do this once per cluster - need it again if you nuke minikube or whatever
  # TODO - could probably query and do this conditionally somehow
  # kapp deploy -a default-ns-rbac -f https://raw.githubusercontent.com/vmware-tanzu/carvel-kapp-controller/develop/examples/rbac/default-ns.yml -y

  kapp deploy -a repo -f distribute/carvel/consumer-repo.yml -y
  echo "allowing 10 seconds for packagerepository to reconcile..."
  sleep 3
  kubectl get packagerepository
  sleep 4
  kubectl get packagerepository
  sleep 3
  kubectl get packagerepository
}

docker_build_and_push
imgpkg_bundle_push
pkgrepo_push
consume_package_repository
kapp deploy -a ${APPNAME} -f distribute/carvel/pkginstall.yml -y
