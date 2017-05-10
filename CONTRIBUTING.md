# Contributing to this repository

# Table of Contents
1. [Commits, release notes and pull requests](#commits-release-notes-pull-requests)
    1. [Fixing a bug](#fixing-a-bug)
    2. [Commits](#commits)
    3. [Release notes](#release-notes)
    4. [Pull requests](#pull-requests)
        1. [Reviewing pull requests](#reviewing-pull-requests)
        2. [Merging pull requests](#merging-pull-requests)
        3. [Backports](#backports)
2. [Documentation impact](#documentation-impact)
    1. [Documenting your change](#documenting-your-change)
    2. [What to document](#what-to-document)
    3. [How to document] (#what-to-document)
3. [Enabling an upstream project in RPCO](#enabling-upstream-project)
    1. [Integrating with OpenStack-Ansible](#integrating-with-osa)
    2. [Beta vs. LA vs. GA](#beta-vs-la-vs-ga)
        1. [Beta](#beta)
        2. [Limited Availability(LA)](#limited-availability)
        3. [General Availability(GA)](#general-availability)
    3. [The details](#the-details)
        1. [Adding the ability to be deployed](#ability-to-deploy)
        2. [Adding the necessary(if any) variables to default variable files](#add-variables)
        3. [Adding ELK configurations](#add-elk-configs)
        4. [Adding the f5 configurations(TBD)](#add-f5-configs)
        5. [Adding MaaS(Monitoring) plugins](#add-maas-plugins)
        6. [Integration tests](#integration-tests)
            1. [Tempest tests](#tempest-tests)
            2. [Adding tests to jenkins-rpc](#adding-tests-to-jenkins-rpc)
4. [Notes](#notes)
5. [Version definitions](#version-definitions)


## Commits, release notes and pull requests<a name="commits-release-notes-pull-requests"></a>
### Fixing a bug<a name="fixing-a-bug"></a>

1. After the bug is triaged and prioritized, make the required changes. New features, breaking changes and other patches of note must include a release note generated using the `reno` tool. Please see `Release Notes` for more information.
2. Make the needed changes following a git workflow that works best for you. [Example Branching workflow](https://git-scm.com/book/en/v2/Git-Branching-Branching-Workflows)
3. Unless a bug is specific to a release branch (e.g. ```liberty-12.1```), commit fixes to the ```master``` branch before any potential backports.
4. Bugs meeting backport criteria are backported to the release branches (e.g. ```liberty-12.1```) as appropriate.
5. Github markdown is used to update the original issue with a checklist for tracking which branches have fixes merged.
6. Each time a PR is merged, the associated branch is deleted from ```rpc-openstack```.
7. When all PRs are completed the issue is then closed.

### Commits<a name="commits"></a>

Please avoid the following in a commit:

* Mixing whitespace changes with functional code changes.
* Mixing two unrelated functional changes in the same commit.
* Sending large new features in a single commit.

Expected git commit message structure:

* The first line should be limited to 50 characters, should not end with a full stop and the first word should be capitalised.
* Use the imperative mood in the subject line - e.g. ```Fix a typo in CONTRIBUTING.md```, ```Remove if/else block in myfile.sh```, ```Eat your dinner```.
* Insert a single blank line after the first line.
* Subsequent lines should be wrapped at 72 characters.
* Provide a detailed description of the change in the following lines, using the guidelines in the section below.
* The last line of the commit should be a reference to the issue being fixed using the keyword 'Connects', e.g.
```
Connects https://github.com/rcbops/rpc-openstack/issues/0
```

In your commit message please consider the following points:

* In the commit subject line, provide a brief description of the change.
* The commit message must be descriptive and contain all the information required to fully understand and review the patch.
* Do not assume the reviewer understands what the original problem was.
* Do not assume the reviewer has access to external web services or site.
* Do not assume the code is self-evident or self-documenting.
* Describe why the change is being made.
* If the commit message suggests an improved code structure, you may be able to split this into two or more commits.
* Ensure sufficient information is provided to review your commit.

### Release notes<a name="release-notes"></a>

A release note must be included in your commit for notable changes and new features. It is generated using the Reno tool. To create a release note:

1. [Install the reno tool](http://docs.openstack.org/developer/reno/installation.html).
2. Generate a new release note file. The YAML file is located under `/releasenotes/notes`.

   `$ reno new <version>`
3. Edit the YAML file. The text uses RST formatting.

Each list item must make sense to read without the context of the patch or the repository the patch is being submitted into. The reason for this is that all release notes are consolidated and presented in a long list without reference to the source patch or the context of the repository.

Each note should be brief and to the point. Try to avoid multi-paragraph notes. For features the note should typically refer to documentation for more details. For bug fixes the note can refer to a registered bug for more details.

In most cases only the following sections should be used for new release notes submitted with patches:

* Features - This section should inform the deployer briefly about a new feature and should describe how to use it either by referencing the variables to set or by referring to documentation.
* Issues - This section should inform the deployer about known issues. This may be used when fixing an issue and wanting to inform deployers about a workaround that can be used for versions prior to that which contains the patch that fixes the issue. Issue notes should specifically make mention of what versions of RPCO are affected by the issue.
* Upgrade - This section should inform the deployer about changes which may affect them when upgrading from a previous major or minor version. Typically, these notes would describe changes to default variable values or variables that have been removed.
* Deprecations - If a variable has been deprecated (ideally using the deprecation filter), then it should be communicated through the notes in this section. Note that if a variable has been removed entirely, then it has not been deprecated and the removal should be noted in the upgrade section.

For more information, see the [Reno project documentation](http://docs.openstack.org/developer/reno/index.html).

### Pull requests<a name="pull-requests"></a>

* A pull request (PR) should ideally contain a single commit
* The PR should include an edited `yaml` release note file describing the changes.
* The PR title and message should contain information relevant to why the commit(s) are happening. This can be based off the commit message.
* The PR description should reference the original issue.
* Where absolutely necessary, related commits can be grouped into a single PR, but this should be the exception, not the rule.

#### Reviewing a pull request<a name="reviewing-pull-requests"></a>

When reviewing a PR, please ensure the included commit(s):

* Actually works to fix the issue.
* Passes the gate checks that are configured to run.
* Contains a single commit, which has a commit message describing the changes involved in the patch. On a rare occasion, multiple related commits in the same PR could be considered.
* Includes a YAML release note file which complies with the release notes guidelines described above.
* Does not overreach. Each commit should be self contained to only address the issue at hand (see above).

#### Merging a pull request<a name="merging-pull-requests"></a>

In order for a PR to be merged, the following criteria should be met:

* All gate tests must have passed.
* There must be at least 2 members of the rcbops engineering team review and give the PR a +1 approval using the review guidelines above.
 * Use GitHub's [pull request reviews](https://help.github.com/articles/about-pull-request-reviews/) function so that your comments are collated into a single review.
 * If a patch is being backported, the person doing the backport cannot vote on it, but the original author of the patch can.
* The second +1 reviewer should merge the patch.

#### Backports<a name="backports"></a>
The owner is responsible for backporting the commit if necessary. Backport pull requests must reference the original issue using the 'Connects' keyword.

## Documentation impact<a name="documentation-impact"></a>

### Documenting your change<a name="documenting-your-change"></a>

When there is a doc impact on your change, you have two choices:

1. Contribute your own doc change to [docs-rpc](https://github.com/rackerlabs/docs-rpc) and tag a relevant docs person for review and merge.
OR
2. Submit an issue to [Docs issues](https://github.com/rackerlabs/docs-rpc/issues)

### What to document<a name="what-to-document"></a>

Documentation is required for:

* Changes to the way playbooks are run/named
* Changes to the documented configuration files
* New feature
* Changes that requires you (as the developer) to take action
* Changes that impact upgrades

### How to document<a name="how-to-document"></a>

The documentation work is all done in [this](https://github.com/rackerlabs/docs-rpc) repo.

1. See the [Docs workflow](https://github.com/rackerlabs/docs-rpc/blob/master/GITHUBING.rst) to setup for contribution and
   [here](https://github.com/rackerlabs/docs-rpc/blob/master/CONTRIBUTING.rst) for our Contributor guidelines.
2. After you create a pull request, tag the doc team for review. See [Documentation team FAQ](https://github.com/rackerlabs/docs-rackspace/blob/master/doc/contributor-collateral/privatecloud-docteam-FAQ.rst) for clarification on who to contact.
3. Await merge. Respond to any questions/comments/concerns.

For any questions about our github processes, contributor guidelines, or FAQ about the docs and team, refer to: [Contributor collatoral](https://github.com/rackerlabs/docs-rackspace/tree/master/doc/contributor-collateral)

## Enabling an upstream project in RPCO<a name="enabling-upstream-project"></a>

### Integrating with OpenStack-Ansible<a name="integrating-with-osa"></a>

Before an OpenStack feature can be integrated into RPCO, it must first be implemented into the OpenStack-Ansible (OSA) project.
For documentation on how to add a service and Ansible role to OpenStack-Ansible, see [this page](http://docs.openstack.org/developer/openstack-ansible/developer-docs/additional-roles.html).

Once the new project is fully integrated into OpenStack-Ansible, it might not be consumable by RPCO yet. Since RPCO and OSA do not have matching development cycles, the project will either have to be backported to a stable branch in OSA (unlikely) or will not be included until RPCO moves on to the release with the new project. For example, if the new project is added into the master branch of OSA (currently Ocata), it will not be consumable by RPCO until RPCO's master branch has been modified to consume OSA's Otaca release. It is recommended to start this integration into OSA 6-12 months before you intend on releasing the feature in RPC.

### Beta vs. LA vs. GA<a name="beta-vs-la-vs-ga"></a>

#### Beta<a name="beta"></a>

When a new OpenStack project or feature is first introduced into RPCO, it will come in as a beta. In order for the project/feature to be qualified as a beta item, it must meet the following criteria:

  * Integration into the OSA project as specified in the above section

It's also important to note that betas are:

  * Not fully supported by Rackspace Support
  * Not considered stable features/projects
  * Not integrated into RPCO automated testing
  * Not deployed by default
  * May not be implemented with HA
  * May not be fully documented

#### Limited Availability (LA)<a name="limited-availability"></a>

Once the feature is out of beta, it will go into LA status. LA features must have the following:

  * Ability to be deployed via our bootstrap and deployment scripts (This is currently being changed as part of https://github.com/rcbops/u-suk-dev/issues/834)
  * All necessary addition of variables inserted in our group_vars/ or, for overrides of OSA existing group_vars, into [user_osa_varibles_defaults.yml](https://github.com/rcbops/rpc-openstack/blob/master/rpcd/etc/openstack_deploy/user_osa_variables_defaults.yml)
  * Integration with RPCO's ELK configurations
  * If the new project has a service that needs to be load-balanced, then f5 support for these services must be added into the [f5-config.py script](https://github.com/rcbops/rpc-openstack/tree/master/scripts#f5-configpy)
  * Must be monitored via a MaaS plugin
  * Documentation on how to deploy the feature/project with RPCO
  * Must be HA
  * Must be fully integrated with RPCO gate jobs
  * Must be fully supported by Rackspace

#### General Availability (GA)<a name="general-availability"></a>

Fully supported features/projects in RPCO must meet the qualifications for a beta, GA, plus the following:

  * Integrated with horizon
  * Must have some supported SDK/CLI tooling


### The details<a name="the-details"></a>

#### Adding the ability to be deployed<a name="ability-to-deploy"></a>
Deployments of features/projects are handled via deployment variables defined in the [``functions.sh``](https://github.com/rcbops/rpc-openstack/blob/master/scripts/functions.sh) script. To add the ability for a feature/project to be deployed, add the proper DEPLOY variable and use that as a trigger to execute the instructions necessary to deploy that feature/project.

The ``functions.sh`` script is sourced in the ``deploy.sh`` script to include these DEPLOY variables. The DEPLOY variables can then be used to deploy a certain feature/project. They are also used in [``bootstrap-aio.yml``](https://github.com/openstack/openstack-ansible/blob/master/tests/bootstrap-aio.yml) to deploy specific scenarios for AIOs.

For more information on the ``deploy.sh`` script, please see https://github.com/rcbops/rpc-openstack/blob/master/scripts/README.rst#deploysh

For more information on the ``bootstrap-aio.yml`` playbook, please see https://github.com/rcbops/rpc-openstack/blob/master/scripts/README.rst

#### Adding the necessary (if any) variables to default variable files<a name="add-variables"></a>
It might be necessary to specify OpenStack-Ansible or RPCO variable overrides so they take new values by default. To override these variables, they must be set in the proper variable files. For more information, please see https://github.com/rcbops/rpc-openstack/blob/master/rpcd/etc/openstack_deploy/README.rst

#### Adding ELK configurations<a name="add-elk-configs"></a>
First, add the filebeat configurations into the filebeat role's [default variable file](https://github.com/rcbops/rpc-openstack/blob/master/rpcd/playbooks/roles/filebeat/defaults/main.yml).
For example, the filebeat configurations for the cinder logs will look like the following:
```yaml

filebeat_logging_paths:
  - paths:
    - '/var/log/cinder/*.log'
    document_type: openstack
    tags:
    - openstack
    - oslofmt
    - cinder
    multiline:
      pattern: "{{ multiline_openstack_pattern }}"
      negate: 'true'
match: after
```
If the service you are adding does not have multiline logging, you may omit the multiline option.

Next, add a logstash filter configuration template file for the service that you are adding. Please make sure to follow the numbering convention used for the other services i.e. ``21_myservice.conf``. For an example, please see:
https://github.com/rcbops/rpc-openstack/blob/master/rpcd/playbooks/roles/logstash/templates/06-cinder.conf
For more documentation about using filters with logstash, please see:
https://www.elastic.co/guide/en/logstash/2.3/advanced-pipeline.html#configuring-grok-filter

Finally, add the template file created above as an item in the ``logstash_post_install.yml`` task file, in the task "Deploy Logstash configuration files": https://github.com/rcbops/rpc-openstack/blob/master/rpcd/playbooks/roles/logstash/tasks/logstash_post_install.yml#L45

#### Adding the f5 configurations<a name="add-f5-configs"></a>
For information on how to add a service to our f5-config.py script, please see https://github.com/rcbops/rpc-openstack/blob/master/scripts/README.rst#f5-configpy

#### Adding MaaS (Monitoring) plugins for new services<a name="add-maas-plugins"></a>
For information on how to create MaaS plugins, please see: https://github.com/rcbops/rpc-openstack/blob/master/maas/plugins/README.md

#### Integration tests<a name="integration-tests"></a>
A new OpenStack project must provide integration testing through either [tempest](http://docs.openstack.org/developer/tempest/) or our [jenkins-rpc](https://github.com/rcbops/jenkins-rpc/blob/master/README.md) gating jobs. Most OpenStack services provide scenario tests as part of the tempest test suite. If not, add integration tests to the ``jenkins-rpc`` CI/CD pipeline that run on each commit.

##### Tempest tests<a name="tempest-tests"></a>
If the introduced OpenStack service has tempest tests, make sure that it is being run as part of our jenkins-rpc gating jobs. The tempest scenarios for these jobs are defined [here](https://github.com/rcbops/jenkins-rpc/blob/59042d04db3c0a906937ed5414866d1b5c66590e/rpc-jobs/jobs.yaml#L6). If these tests don't include the new service, then make a PR against jenkins-rpc to modify this variable. Keep in mind that it is assumed these tests are already fully integrated into OpenStack-Ansible's [``openstack_tempest_gate.sh``](https://github.com/openstack/openstack-ansible-os_tempest/blob/stable/newton/templates/openstack_tempest_gate.sh.j2) script.

##### Adding tests to jenkins-rpc<a name="adding-tests-to-jenkins-rpc"></a>
If the OpenStack service does not have tempest tests, then it is required for some form of functional and/or integration testing be added as part of the jenkins-rpc CI/CD pipeline. For example, the holland service has a [playbook](https://github.com/rcbops/jenkins-rpc/blob/master/scripts/test_holland.yml) to perform tests [at the end](https://github.com/rcbops/jenkins-rpc/blob/59042d04db3c0a906937ed5414866d1b5c66590e/scripts/gating_bash_lib.sh#L369) of an AIO job. A simliar playbook can be added for the newly introduced OpenStack service. Once a playbook has been created, create a function in ``gating_bash_lib.sh``, and invoke it in the [``run_tests``](https://github.com/rcbops/jenkins-rpc/blob/master/scripts/gating_bash_lib.sh#L369) function.

## Notes<a name="notes"></a>
- ```master``` branch is always the 'current' branch where development for the next minor or major release is taking place
- Named branches (e.g. ```liberty-12.1```, or ```mitaka-13.2```) are release branches where releases are tagged
- All branches have gating enabled, and patches should not be merged that do not pass gating
- QE testing is only performed on major (e.g. ```12.0.0```) and minor (e.g. ```12.1.0```) releases, not on patch (e.g. ```12.1.5```) releases, which are assumed to be adequately tested by the commit based, and periodic, jenkins gating.

## Version definitions<a name="version-definitions"></a>

**Major release**

  * OpenStack release
  * Possibly a new feature (?)

**Minor release**

  * Big change within a release
  * Security  - upgrade-impacting
  * Bug fixes - upgrade-impacting
  * Features
  * SHA bumps

**Patch release**

  * Security  - non-upgrade-impacting
  * Bug fixes - non-upgrade-impacting
