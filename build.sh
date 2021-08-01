#!/bin/bash

set -eux

VERSION=v1
REPOTAG=jkimmelvmware/toy-projects:artificialtweetener-$VERSION

docker build . -t ${REPOTAG}
# may need to `docker login --username="jkimmelvmware"` if access is denied
docker push ${REPOTAG}

cat > distribute/carvel/package-contents/config/values.yml <<- EOF
#@data/values
---
docker_image: ${REPOTAG}
EOF

