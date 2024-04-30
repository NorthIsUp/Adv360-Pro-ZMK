DOCKER := $(shell { command -v podman || command -v docker; })
TIMESTAMP := $(shell date -u +"%Y%m%d%H%M")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)
ifeq ($(shell uname),Darwin)
SELINUX1 :=
SELINUX2 :=
else
SELINUX1 := :z
SELINUX2 := ,z
endif

# run 'make all BUILD_IMAGE=true' to build the docker image locally
BUILD_IMAGE ?= false

# override the dockerhub organization and tag with make cli args
# e.g. make all DOCKER_ORG=myorg IMAGE_TAG=mytag
DOCKER_ORG ?= kinesis
IMAGE_TAG ?= latest
DOCKER_IMAGE = $(DOCKER_ORG)/zmk-adv360:$(IMAGE_TAG)

.PHONY: all left clean_firmware clean_image clean

# build the docker image locally if BUILD_IMAGE is true
# otherwise pull the docker image from dockerhub
docker_image:
ifeq ($(BUILD_IMAGE),true)
	$(DOCKER) build --tag $(DOCKER_IMAGE) --file Dockerfile .
else
	$(DOCKER) pull docker.io/$(DOCKER_IMAGE)
endif

all: BUILD_RIGHT=true
all: build_firmware

left: BUILD_RIGHT=false
left: build_firmware

build_firmware: docker_image
build_firmware:
	$(shell bin/get_version.sh >> /dev/null)
	$(DOCKER) rm zmk 2>/dev/null || true
	$(DOCKER) run --rm -it --name zmk \
		-v $(PWD)/firmware:/app/firmware$(SELINUX1) \
		-v $(PWD)/config:/app/config:ro$(SELINUX2) \
		-e TIMESTAMP=$(TIMESTAMP) \
		-e COMMIT=$(COMMIT) \
		-e BUILD_RIGHT=$(BUILD_RIGHT) \
		$(DOCKER_IMAGE)
	rm config/version.dtsi


clean_firmware:
	rm -f firmware/*.uf2

clean_image:
	$(DOCKER) image rm zmk docker.io/zmkfirmware/zmk-build-arm:stable

clean: clean_firmware clean_image
