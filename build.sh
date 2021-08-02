#!/bin/bash

set -eux

VERSION=v1
REPOTAG=jkimmelvmware/toy-projects:artificialtweetener-$VERSION
REPOHOST="https://index.docker.io"

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
cat > ${VERSION}.yml <<- EOF
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: artificial-tweetener.github.com.${VERSION}
spec:
  refName: artificial-tweetener.github.com
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
      - kap: {}
EOF

kbld -f distribute/carvel/my-pkg-repo/packages/ --imgpkg-lock-output distribute/carvel/my-pkg-repo/.imgpkg/images.yml

imgpkg push -b ${REPO_HOST}/${REPOTAG} -f distribute/carvel/my-pkg-repo
