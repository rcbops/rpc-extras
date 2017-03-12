/* This function returns a function that will be executed multiple times in
 * parallel. It builds a sub job, then links that sub-job to the pull request
 * that triggered this build.
 */
def makeBuildStep(job, parameters, context){
  return {
    def number = 0
    def state = ""
    def result = build job: job, parameters: parameters, propagate: false
    print("Sub build ${job} result: ${result.result}")
    if (result.result == "SUCCESS"){
      state = "success"
    } else {
      state = "failure"
      currentBuild.result = 'Failure'
    }
    // No point trying to update a PR if this was not triggered by a PR.
    // CHANGE_ID is only set for PR builds, so will fail early for branch
    // builds.
    try {
      print("Updating PR ${CHANGE_ID}")
      try{
        //can't get build number if the build aborted.
        number = result.getNumber()
        print("Sub build ${job} number: $number")
      }catch (e) {
        print("Failed to get build number for child job, Aborted?")
      }
      lint_container.inside {
        withCredentials([
          string(
            credentialsId: "rpc-jenkins-svc-github-pat",
            variable: "GITHUB_PAT"
          )
        ]){
          sh """#!/bin/bash
            python2.7 rpc-gating/scripts/ghstatus.py ${job} ${number} ${state} ${context}
          """
        }
      } // inside
    }catch (e){
      print("Failed to set PR status, maybe this job was not triggered by PR? ${e}")
    }// if
  } // closure
} // func

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
      print("RPC Gating branch: ${env.RPC_GATING_BRANCH}")
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
        "continuous-integration/jenkins/aio/swift"),
      "ceph": makeBuildStep(
        "scratchpipeline",
        [
          [$class: 'BooleanParameterValue',
           name: 'fail',
           value: false],
        ],
        "continuous-integration/jenkins/aio/ceph")
    ])
  }
}
