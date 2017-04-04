def makeBuildStep(job, parameters, context){
  return {
    result = build job: job, parameters: parameters, propagate: false
    if (result.result == "success"){
      state = "success"
    } else {
      state = "error"
    }
    lint_container.inside {
      sh "python2.7 rpc-gating/scripts/ghstatus.py -- ${job} ${state} ${context}"
    }
  }
}

properties([
  parameters([
    string(name: 'RPC_GATING_BRANCH', defaultValue: 'bug/1080_Jenkinsfile_Trigger'),
    string(name: 'RPC_GATING_REPO', defaultValue: 'https://github.com/rcbops/rpc-gating')
  ])
])
node(){
  deleteDir()
  stage("Prepare"){
    dir("rpc-gating"){
      git branch: env.RPC_GATING_BRANCH, url: env.RPC_GATING_REPO
    }
    dir("rpc-openstack"){
      checkout scm
      lint_container = docker.build 'lint'
    }
  }
  stage("Lint"){
    lint_container.inside {
      checkout scm
      sh """
        # using the workspace results in a venv path too long for a shebang
        # which means that the venv pip can't be executed.
        # The dir() jenkinsfile step doesn't work within docker.inside.
        # https://issues.jenkins-ci.org/browse/JENKINS-33510
        git submodule update --init
        TOX_WORK_DIR=/tmp tox -e flake8,ansible-lint,releasenotes,bashate,release-script
      """
    }
  }
  stage("AIO"){
    parallel ([
      "swift": makeBuildStep(
        "scratchpipeline",
        [
          [$class: 'BooleanParameterValue',
           name: 'fail',
           value: false],
        ],
        "swift"),
      "ceph": makeBuildStep(
        "scratchpipeline",
        [
          [$class: 'BooleanParameterValue',
           name: 'fail',
           value: true],
        ],
        "ceph")
    ])
  }
}
