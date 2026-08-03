engine := env_var_or_default("CONTAINER_ENGINE", "docker")

all: build push

build:
    {{engine}} build -t overlay-builder:latest -t codeberg.org/slashpotato/overlay-builder:latest .

push:
    {{engine}} push codeberg.org/slashpotato/overlay-builder:latest

