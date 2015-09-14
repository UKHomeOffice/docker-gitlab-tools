#!/bin/bash

GO_CRON=${GO_CRON:-/go-cron}
$GO_CRON "${SCHEDULE}" /bin/bash -c "/bin/gitlab-alert.rb $@"
