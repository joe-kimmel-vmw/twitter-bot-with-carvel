#!/bin/bash

set -eux

IMGVERSION=0.1.0
IMGREPOPATH="jkimmelvmware/toy-projects:artificialtweetener"
IMGREPOTAG=${IMGREPOPATH}-${IMGVERSION}
PKGVERSION=1.0.0
PKGREPOPATH="jkimmelvmware/my-pkg-repo:packages"
PKGREPOTAG=${PKGREPOPATH}-${PKGVERSION}
REPOHOST="index.docker.io"
APPNAME="artificial-tweetener.github.com"

docker build . -t ${IMGREPOTAG}
# may need to `docker login --username="jkimmelvmware"` if access is denied
docker push ${IMGREPOTAG}

cat > distribute/carvel/package-contents/config/values.yml <<- EOF
#@data/values
---
docker_image: ${IMGREPOTAG}
EOF

kbld -f distribute/carvel/package-contents/config/ --imgpkg-lock-output distribute/carvel/package-contents/.imgpkg/images.yml

imgpkg push -b ${REPOHOST}/${IMGREPOTAG} -f distribute/carvel/package-contents/

# TODO (should i do this with ytt instead?)
cat > distribute/carvel/my-pkg-repo/packages/artificial-tweetener.github.com/${IMGVERSION}.yml <<- EOF
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: ${APPNAME}.${IMGVERSION}
spec:
  refName: ${APPNAME}
  version: ${IMGVERSION}
  releaseNotes: try not to be so jealous
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: ${REPOHOST}/${IMGREPOTAG}
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

cat > distribute/carvel/consumer-repo.yml <<- EOF
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: simple-package-repository
spec:
  fetch:
    imgpkgBundle:
      image: ${REPOHOST}/${IMGREPOTAG}
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

# kapp deploy -a default-ns-rbac -f https://raw.githubusercontent.com/vmware-tanzu/carvel-kapp-controller/develop/examples/rbac/default-ns.yml -y

kapp deploy -a repo -f distribute/carvel/consumer-repo.yml -y
echo "allowing 10 seconds for packagerepository to reconcile..."
sleep 3
kubectl get packagerepository
sleep 4
kubectl get packagerepository
sleep 3
kubectl get packagerepository

kapp deploy -a ${APPNAME} -f distribute/carvel/pkginstall.yml -y
