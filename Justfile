build-env:
    docker build -t bluebuild-local .

build: build-env
    docker run --rm \
        -v "$(pwd):/work" \
        -v "$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock" \
        -e DOCKER_API_VERSION=1.41 \
        bluebuild-local \
        bluebuild build recipes/recipe.yml

build-env-podman:
    podman build -t bluebuild-local .

build-podman: build-env-podman
    systemctl --user start podman.socket
    podman run --rm \
        -v "$(pwd):/work" \
        -v "$XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock" \
        -e DOCKER_API_VERSION=1.41 \
        --security-opt label=disable \
        bluebuild-local \
        bluebuild build recipes/recipe.yml
