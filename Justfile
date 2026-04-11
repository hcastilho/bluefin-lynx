build-env:
    docker build -t bluebuild-local .

build: build-env
    docker run --rm \
        -v "$(pwd):/work" \
        -v "$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock" \
        -e DOCKER_API_VERSION=1.41 \
        bluebuild-local \
        bluebuild build recipes/recipe.yml
