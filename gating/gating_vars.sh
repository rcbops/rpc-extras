# These vars are set by the CI environment, but are given defaults
# here to cater for situations where someone is executing the test
# outside of the CI environment.
export RE_JOB_IMAGE="${RE_JOB_IMAGE:-xenial_no_artifacts}"
export RE_JOB_SCENARIO="${RE_JOB_SCENARIO:-swift}"
export RE_JOB_ACTION="${RE_JOB_ACTION:-deploy}"
export RE_JOB_FLAVOR="${RE_JOB_FLAVOR:-}"
export RE_JOB_TRIGGER="${RE_JOB_TRIGGER:-USER}"
export RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"
export RE_JOB_NAME="${RE_JOB_NAME:-${RE_JOB_TRIGGER}_rpc-openstack-master-${RE_JOB_IMAGE}_no_artifacts-${RE_JOB_SCENARIO}-${RE_JOB_ACTION}}"
