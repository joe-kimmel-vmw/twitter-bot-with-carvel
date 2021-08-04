#!/bin/bash

set -eux

VERSION=0.1.0
REPOTAG=jkimmelvmware/toy-projects:artificialtweetener-$VERSION
REPOHOST="index.docker.io"
APPNAME="artificial-tweetener.github.com"

docker build . -t ${REPOTAG}
# may need to `docker login --username="jkimmelvmware"` if access is denied
docker push ${REPOTAG}

cat > distribute/carvel/package-contents/config/values.yml <<- EOF
#@data/values
---
docker_image: ${REPOTAG}
EOF

kbld -f distribute/carvel/package-contents/config/ --imgpkg-lock-output distribute/carvel/package-contents/.imgpkg/images.yml

imgpkg push -b ${REPOHOST}/${REPOTAG} -f distribute/carvel/package-contents/

# TODO (should i do this with ytt instead?)
cat > distribute/carvel/my-pkg-repo/packages/artificial-tweetener.github.com/${VERSION}.yml <<- EOF
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: ${APPNAME}.${VERSION}
spec:
  refName: ${APPNAME}
  version: ${VERSION}
  releaseNotes: try not to be so jealous
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: ${REPOHOST}/${REPOTAG}
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

imgpkg push -b ${REPOHOST}/${REPOTAG} -f distribute/carvel/my-pkg-repo

cat > distribute/carvel/consumer-repo.yml <<- EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: simple-package-repository
spec:
  fetch:
    imgpkgBundle:
      image: ${REPOHOST}/packages/my-pkg-repo/${VERSION}
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
      constraints: ${VERSION}
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

# kapp deploy -a default-ns-rbac -f https://raw.githubusercontent.com/vmware-tanzu/carvel-kapp-controller/develop/examples/rbac/default-ns.yml -y

kapp deploy -a ${APPNAME} -f distribute/carvel/pkginstall.yml -y
