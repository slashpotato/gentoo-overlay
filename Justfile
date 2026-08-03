engine := env_var_or_default("CONTAINER_ENGINE", "docker")

all: update push

update:
    {{engine}} build -t codeberg.org/slashpotato/overlay-builder:latest .

bootstrap:
    {{engine}} build -f Dockerfile.bootstrap -t codeberg.org/slashpotato/overlay-builder:latest .

push:
    {{engine}} push codeberg.org/slashpotato/overlay-builder:latest

