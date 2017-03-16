/* Set status on a github PR */
def set_status(job, number, state, context){
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
}

/* This function returns a function that will be executed multiple times in
* parallel. It builds a sub job, then links that sub-job to the pull request
* that triggered this build.
*/
def makeBuildStep(job, parameters, context){
  return {
    def number = 0
    def state = ""
    def result = ""

    print("Building ${job} with params: ${parameters}")
    try{
      result = build job: job, parameters: parameters, propagate: false
    }catch (e){
      print (e)
    }
   // To get a build number before the child job as finished, the build would
   // have to be async, and I'm not sure how to get the final result in that
   // case.
   //set_status(job, insert_build_number_here, "pending", context)

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
      set_status(job, number, state, context)
    }catch (e){
      print("Failed to set PR status, maybe this job was not triggered by PR? ${e}")
    }// try
  } // closure
} // func

def determine_series_and_trigger(){
  try {
    series=CHANGE_TARGET
    print("Using CHANGE_TARGET for series, value: ${env.CHANGE_TARGET}")
    trigger="pr"
    rpco_branch="origin/pr/${CHANGE_ID}/merge"
    return [series, trigger, rpco_branch]
  }catch (e){
    rpco_branch=BRANCH_NAME
    trigger="periodic"
    print("Couldn't determine series using CHANGE_TARGET, trying containing branches.")

    /* Determine series (mitaka, newton, master etc) by finiding the newest
       branch that contains the first common commit. The problem is that some
       branches/PRs contain multiple commits, so we start of looking at
       HEAD^, then HEAD^^, HEAD^^^ etc until a branch match is found.
    */

    // Determine the series by finding the latest branch
    // that contains the parent commit
    containing_branches = sh(
      returnStdout: true,
      script: "cd rpc-openstack; git branch -r --contains HEAD^ |sed 's+^ *origin/\\([^/ ]*\\).*\$+\\1+'"
    ).trim().split()

    versions = ['master', 'pike', 'ocata','newton','mitaka',
                'liberty', 'kilo', 'juno']


    for (def ancestor_i=0; ancestor_i<100; ancestor_i++){
      containing_branches = sh(
        returnStdout: true,
        script: "cd rpc-openstack; git branch -r --contains HEAD~${ancestor_i} |sed 's+^ *origin/\\([^/ ]*\\).*\$+\\1+'"
      ).trim().split()
      print("Commits from tip: ${ancestor_i} branches that contain this commit: ${containing_branches}")
      if (containing_branches.size() == 0){
        continue
      }
      for (def version_i=0; version_i < versions.size(); version_i++){
        candidate = versions[version_i]
        for (def c_branch_i=0;
             c_branch_i < containing_branches.size(); c_branch_i++){
          cont_branch = containing_branches[c_branch_i]
          if (cont_branch.contains(candidate)){
            print("Found common ancestor in branch ${cont_branch} ${ancestor_i} commits from tip.")
            return [candidate, trigger, rpco_branch]
          } // if
        }// for containing_branches
      }// for versions
    }// for ancestor
    throw new Exception("Failed to determine series")
  } //catch
}//func

properties([
  parameters([
    string(name: 'RPC_GATING_BRANCH', defaultValue: 'master'),
    string(name: 'RPC_GATING_REPO', defaultValue: 'https://github.com/rcbops/rpc-gating')
  ])
])
node(){
  sh "env"
  // sometimes pipeline param defaults are not populated :sadpanda:
  try{
    print("Using rpc-gating branch: ${RPC_GATING_BRANCH}")
  } catch (e){
    print ("Parameter not supplied: ${e}. Using rcbops/rpc-gating@master")
    env.RPC_GATING_BRANCH='master'
    env.RPC_GATING_REPO='https://github.com/rcbops/rpc-gating'
  }
  deleteDir()
  stage("Prepare"){
    dir("rpc-gating"){
      print("RPC Gating branch: ${env.RPC_GATING_BRANCH}")
      git branch: env.RPC_GATING_BRANCH, url: env.RPC_GATING_REPO
    }
    dir("rpc-openstack"){
      checkout scm
      rpc_sha = sh(
        returnStdout: true,
        script: "git rev-parse HEAD"
      ).trim()
      rpc_repo = sh(
        returnStdout: true,
        script: "git remote -v |awk '/origin.*fetch/{print \$2}'"
      ).trim().split()[0]
      lint_container = docker.build 'lint'
    }
  }
  r = determine_series_and_trigger()
  series = r[0]
  trigger = r[1]
  rpco_branch = r[2]
  print("Series: ${series} Trigger: ${trigger}")
  stage("Lint"){
    lint_container.inside {
      sh """
        # using the workspace results in a venv path too long for a shebang
        # which means that the venv pip can't be executed.
        # The dir() jenkinsfile step doesn't work within docker.inside.
        # https://issues.jenkins-ci.org/browse/JENKINS-33510
        cd rpc-openstack
        git submodule update --init
        TOX_WORK_DIR=/tmp tox -e flake8,ansible-lint,releasenotes,bashate,release-script
      """
    }
  }
  stage("AIO"){
    parallel_steps = [:]
    def user_vars = []
    common_params = [
      [
        $class: 'StringParameterValue',
        name: 'RPC_BRANCH',
        value: rpco_branch
      ],
      [
        $class: 'StringParameterValue',
        name: 'RPC_REPO',
        value: rpc_repo
      ],
      [
        $class: 'StringParameterValue',
        name: 'RPC_GATING_REPO',
        value: RPC_GATING_REPO
      ],
      [
        $class: 'StringParameterValue',
        name: 'RPC_GATING_BRANCH',
        value: RPC_GATING_BRANCH
      ]
    ]
    if (trigger == "pr"){
      user_vars.add("maas_use_api: false\n")
    }
    parallel_steps["swift"] =  makeBuildStep(
        "RPC-AIO",
        common_params + [
          [
            $class: 'StringParameterValue',
            name: 'USER_VARS',
            value: user_vars.join("\n")
          ]
        ],
        "continuous-integration/jenkins/aio/swift"
    )
    parallel_steps["ceph"] = makeBuildStep(
        "RPC-AIO",
        common_params +
        [
          [
            $class: 'StringParameterValue',
            name: 'USER_VARS',
            value: user_vars.join("\n") +
"""cinder_cinder_conf_overrides:
    DEFAULT:
        default_volume_type: ceph
cinder_service_backup_driver: cinder.backup.drivers.ceph
cinder_service_backup_program_enabled: true
"""
          ],
          [
            $class: 'StringParameterValue',
            name: 'DEPLOY_CEPH',
            value: 'yes'
          ],
        ],
        "continuous-integration/jenkins/aio/ceph"
    )
    if (["newton", "master"].contains(series)){
      parallel_steps["xenial"] = makeBuildStep(
          "RPC-AIO",
          common_params +
          [
            [
              $class: 'StringParameterValue',
              name: 'USER_VARS',
              value: user_vars.join("\n")
            ],
            [
              $class: 'StringParameterValue',
              name: 'IMAGE',
              value: 'Ubuntu 16.04 LTS (Xenial Xerus) (PVHVM)'
            ]
          ],
          "continuous-integration/jenkins/aio/xenial"
      )
    }
    if(series == "mitaka"){
      parallel_steps["upgrade"] = makeBuildStep(
          "RPC-AIO",
          common_params +
          [
            [
              $class: 'StringParameterValue',
              name: 'USER_VARS',
              value: user_vars.join("\n")
            ],
            [
              $class: 'StringParameterValue',
              name: 'STAGES',
              value: 'Allocate Resources, Connect Slave, Prepare Deployment, Deploy RPC w/ Script, Install Tempest, Tempest Tests, Upgrade, Cleanup'
            ]
          ],
          "continuous-integration/jenkins/aio/upgrade"
      )
    }
    parallel parallel_steps
  }
}
