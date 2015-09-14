#!/bin/bash

SCHEDULE=${SCHEDULE:-""}
GO_CRON=${GO_CRON:-/go-cron}
$GO_CRON "${SCHEDULE}" bin/bash -c "/gitlab-alert.rb"
