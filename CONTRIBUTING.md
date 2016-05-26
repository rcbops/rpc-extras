# Contributing to this repository

#### Notes
- ```master``` branch is always the 'current' branch where development for the next minor or major release is taking place
- Named branches (e.g. ```liberty-12.1```, or ```mitaka-13.2```) are release branches where releases are tagged
- All branches have gating enabled, and patches should not be merged that do not pass gating
- QE testing is only performed on major (e.g. ```12.0.0```) and minor (e.g. ```12.1.0```) releases, not on patch (e.g. ```12.1.5```) releases, which are assumed to be adequately tested by the commit based, and periodic, jenkins gating.

#### Version definitions

**Major release**

  * OpenStack release
  * Possibly a new feature (?)

**Minor release**
  
  * Big change within a release
  * Security  - upgrade-impacting
  * Bug fixes - upgrade-impacting
  * Features
  * sha bumps
   
**Patch release**
  
  * Security  - non-upgrade-impacting
  * Bug fixes - non-upgrade-impacting

## Working in the repository

### Filing a bug report

File a bug or requested feature against ```rpc-openstack```. Please include the following information:

* The branch (or tag) which you encountered this issue.
* Steps to reproduce the issue.
* Any output or logs from your environment.

### Fixing a bug


1. After the bug is triaged and prioritised, make the required changes. New features, breaking changes and other patches of note must include a release note generated using the `reno tool`. Please see `Release Notes` for more information.
2. Push changes directly to a branch on ```rpc-openstack``` in the ```rcbops``` github namespace (rather than a developers own fork). A pull request is then made from this branch to the ```master``` branch.
3. Unless a bug is specific to a release branch (e.g. ```liberty-12.1```), commit fixes to the ```master``` branch before any potential backports.
4. Bugs meeting backport criteria are backported to the release branches (e.g. ```liberty-12.1```) as appropriate.
5. Github markdown is used to update the original issue with a checklist for tracking which branches have fixes merged.
6. Each time a PR is merged, the associated branch is deleted from ```rpc-openstack```.
7. When all PRs are completed the issue is then closed.

## Documentation impact

### documenting your change

When noting there is a doc impact on your change, you have two choices:

1. Submit an issue to [Docs issues](https://github.com/rackerlabs/docs-rpc/issues)
OR
2. Contribute your own doc change to [docs-rpc](https://github.com/rackerlabs/docs-rpc) and tag a relevant docs person for review and merge.

### what to document

Document changes if:

* There are changes to the way playbooks are run/named
* Changes to the documented configuration files
* New feature
* Change that requires you (as the developer) to take action
* Update impact changes

### how to document

The documentation work is all done in [this](https://github.com/rackerlabs/docs-rpc) repo.

1. See the [Docs workflow](https://github.com/rackerlabs/docs-rpc/blob/master/GITHUBING.rst) to setup for contribution and
   [here](https://github.com/rackerlabs/docs-rpc/blob/master/CONTRIBUTING.rst) for our Contributor guidelines.
2. Once you have created a pull request, tag the doc team for review. See [Documentation team FAQ](https://github.com/rackerlabs/docs-rackspace/blob/master/doc/contributor-collateral/privatecloud-docteam-FAQ.rst) for clarification on who to contact.
3. Await merge. Respond to any questions/comments/concerns.

Any further questions about our github processes, contributor guidelines, or FAQ about the docs and team, refer to: [Contributor collatoral](https://github.com/rackerlabs/docs-rackspace/tree/master/doc/contributor-collateral) 

## Commits, release notes and pull requests

### Commits

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

In your commit message please consider the following points:

* In the commit subject line, provide a brief description of the change.
* The commit message must be descriptive and contain all the information required to fully understand and review the patch.
* Do not assume the reviewer understands what the original problem was.
* Do not assume the reviewer has access to external web services or site.
* Do not assume the code is self-evident or self-documenting.
* Describe why the change is being made.
* If the commit message suggests an improved code structure, you may be able to split this into two or more commits.
* Ensure sufficient information is provided to review your commit.

### Release notes

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

### Pull requests

* A pull request (PR) should ideally contain a single commit
* The PR should include an edited `yaml` release note file describing the changes.
* The PR title and message should contain information relevant to why the commit(s) are happening. This can be based off the commit message.
* The PR description should reference the original issue.
* Where absolutely necessary, related commits can be grouped into a single PR, but this should be the exception, not the rule.

#### Reviewing a pull request

When reviewing a PR, please ensure the included commit(s):

* Actually works to fix the issue.
* Passes the gate checks that are configured to run.
* Contains a single commit, which has a commit message describing the changes involved in the patch. On a rare occasion, multiple related commits in the same PR could be considered.
* Includes a YAML release note file which complies with the release notes guidelines described above.
* Does not overreach. Each commit should be self contained to only address the issue at hand (see above).

#### Merging a pull request

In order for a PR to be merged, the following criteria should be met:

* All gate tests must have passed.
* There must be at least 2 members of the rcbops engineering team review and give the PR a +1 approval using the review guidelines above.
 * If a patch is being backported, the person doing the backport cannot vote on it, but the original author of the patch can.
* The second +1 reviewer should merge the patch.

## Release workflow

### Major and minor releases
1. Work (meaning bugfixes and feature development) is performed in the ```master``` branch in preparation for a major or minor release (e.g. ```12.0.0``` or ```12.2.0```).
2. When all criteria for the targeted release are fulfilled, a release branch is created using the naming convention **series-Major.minor** (e.g. ```liberty-12.0```, or ```mitaka-13.1```), and an rc tag created (e.g. ```r12.0.0rc1```). This tag is then passed to the QE team for initial testing.
3. Work continues in ```master``` on features and bugs targeted at the next major or minor release (e.g. ```12.1.0```).
4. As QE (and potentially support and other teams) progress their testing on the release candidate, bugs will be identified in the rc tag that was handed to them. These bugs should be fixed in ```master``` and cherry-picked to the release branch. **No other bug fixes should be cherry-picked into this branch** so that this branch can remain a non-moving target for QE.
5. Once all bugs from the initial release candidate have been cherry-picked into the release branch, a new release candidate should be tagged (e.g. ```r12.0.0rc2```).
6. Steps 4-5 should be repeated until the latest rc passes all QE tests satisfactorily.
7. Once QE are satisfied, a release tag (e.g. ```r12.0.0```) is created in the release branch.

### Patch releases
1. Work (bugfixes) is performed in the ```master``` branch and cherry-picked into the release branch (e.g. ```liberty-12.1``` or ```mitaka-13.1```). OR work (bugfixes) is performed directly in the release branch if it is release specific and doesn't affect ```master```.
2. Every 2 weeks (approximately) a new release tag (e.g. ```12.1.1```) is made.
3. Immediately after tagging, all external projects included either via submodules, ansible-galaxy or some other mechanism, will have the version/revision/SHA updated to point to the HEAD of that project (in vernacular, we'll do a SHA bump). This allows an immediate set of gate jobs to run on those SHA bumps, as well as the next 2 weeks of development to happen against those new SHA's. This will allow us to stay current and only have to cope with incremental change in external projects. 

[1]
```
sample markdown for checklist

---
- [x] master PR: https://github.com/rcbops/rpc-openstack/pull/{{number}}
- [] kilo PR: https://github.com/rcbops/rpc-openstack/pull/{{number}}
```

