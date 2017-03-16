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
        python2.7 rpc-gating/scripts/ghstatus.py "${job}" "${number}" "${state}" "${context}"
      """
    }
  } // inside
}

/* This function returns a function that will be executed multiple times in
* parallel. It builds a sub job, then links that sub-job to the pull request
* that triggered this build.
*/
def makeBuildStep(job, parameters, context, trigger, pushto){
  return {
    def number = 0
    def state = ""
    def result = ""

    print("Building ${job} with params: ${parameters}")
    if(trigger == "pr"){
      set_status(job, 0, "pending", context)
    }
    try{
      result = build job: job, parameters: parameters, propagate: false
    }catch (e){
      print (e)
    }

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
    if (trigger == "pr"){
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
        print("Failed to set PR status, error: ${e}")
      } // try
    }else if(trigger == "periodic"
             && pushto != ""
             && state == "success"){
      print "Attempting to push to ${pushto}"
      dir("rpc-openstack"){
        sshagent (credentials:['rpc-jenkins-svc-github-ssh-key']){
          sh """
            mkdir -p ~/.ssh
            ssh-keyscan github.com >> ~/.ssh/known_hosts
            git push -f git@github.com:rcbops/rpc-openstack HEAD:${pushto}
            """
        } // sshagent
      } // dir
    } // if
  } // closure
} // func

def determine_series_and_trigger(){
  try {
    series=CHANGE_TARGET.split("-")[0]
    print("Using CHANGE_TARGET for series, value: ${env.CHANGE_TARGET}")
    trigger="pr"
    rpco_branch="pr/${CHANGE_ID}/merge"
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


def aio_job_name(series, context, trigger){
  return "RPC-AIO_${series}-${context}-${trigger}"
}

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
      lint_container = docker.build env.BUILD_TAG.toLowerCase()
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
    parallel_steps["swift"] =  makeBuildStep(
        aio_job_name(series, "swift", trigger),
        common_params,
        "continuous-integration/jenkins/aio/swift",
        trigger,
        ""
    )
    parallel_steps["ceph"] = makeBuildStep(
        aio_job_name(series, "ceph", trigger),
        common_params,
        "continuous-integration/jenkins/aio/ceph",
        trigger,
        ""
    )
    if (["newton", "master"].contains(series)){
      parallel_steps["xenial"] = makeBuildStep(
          aio_job_name(series, "xenial", trigger),
          common_params,
          "continuous-integration/jenkins/aio/xenial",
          trigger,
          ""
      )
    }
    if(series == "mitaka"){
      parallel_steps["upgrade"] = makeBuildStep(
          aio_job_name(series, "upgrade", trigger),
          common_params,
          "continuous-integration/jenkins/aio/upgrade",
          trigger,
          ""
      )
    }
    /* Using branch name instead of series as we want to target builds
    of the master branch, not PRs targetting the master branch
    */
    if(env.BRANCH_NAME == "master" && trigger == "periodic"){
      parallel_steps["omna"] = makeBuildStep(
          'OnMetal_Multi_Node_AIO_master-xenial',
          common_params,
          "continuous-integration/jenkins/aio/omna",
          trigger,
          "omna_approved"
      )
    }
    parallel parallel_steps
  }
}
