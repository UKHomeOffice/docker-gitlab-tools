#
#  vim:ts=2:sw=2:et
#
NAME=gitlab-alert
AUTHOR=gambol99

.PHONY: build test

default: build

build:
	sudo docker build -t ${AUTHOR}/${NAME} .
