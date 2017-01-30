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

# Issue workflow

### Definitions
#### Issues
Issues are work items, they may be bugs or enhancements. They are managed using [Waffle](https://waffle.io/rcbops/u-suk-dev?source=rcbops%2Frpc-openstack) and stored in [GitHub](https://github.com/rcbops/rpc-openstack/issues). Issues that are logged in other places, for example on Launchpad for OSA, are not within scope unless they have been reported on this project by the creation of a new issue to track the upstream item.

Each individual issue should be viewed as tracking all the steps required to release one commit as part of the product. So, if an issue requires changes made in multiple pull requests to a single branch those changes should be broken out into separate issues however, if the commit requires backports they do form part of the same issue.

#### Waffle board
The [Waffle board](https://waffle.io/rcbops/u-suk-dev?source=rcbops%2Frpc-openstack) is a Kanban board consisting of a series of columns used to manage the progress of issues. This board is the only place to view or update the current work commitments.

#### WIP (Work In Progress)
An issue is WIP when it is in one of the columns, on the board, between Backlog and Done. Put another way, the only times an issue does not count as WIP are if it is in Backlog or Done.

#### WIP limits
Most columns on the board have a maximum WIP limit that is used to throttle the amount of new work to which the engineering team commits. Approved also has a minimum WIP limit that is used as a mechanism to initiate the process of pulling new work into Backlog. The current WIP limits can be found by filtering the Waffle board on the relevant swim lane to highlight the appropriate WIP limit card in Backlog. No column can receive new work if it violates the WIP limit unless there is an explicit exception made for it as defined in the processes below.

#### Swim lanes
Each swim lane represents a category of WIP, for example bugs or enhancements. The board is divided into swim lanes using labels.

#### Stakeholders
* reporter - the individual that created the issue.
* owner(s) - the individual(s) assigned to manage the issue through to its closure.
* reviewer(s) - the individual(s) who review a pull request and provide feedback.

#### Labels
Labels are used to categorise issues to aid with tracking and prioritisation.

|Type                     |Label name               |Description                                                                                                                                                   |Examples                                                                                      |
|-------------------------|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
|Issue type               |type-bug                 |Defects affecting the RPCO project.                                                                                                                           |                                                                                              |
|Issue type               |type-enhancement         |New feature that require tracking by the product team.                                                                                                   |Adding a new OpenStack service.                                                                    |
|Issue type               |type-undecided           |Used when there is not enough information provided to determine the type.                                                                                     |                                                                                              |
|Team affected            |impacts-qe               |Identifies issues that affect the QE team.                                                                                                                    |                                                                                              |
|Team affected            |impacts-support          |Identifies issues that affect the Support team.                                                                                                               |                                                                                              |
|Team affected            |impacts-onboarding       |Identifies issus that are suitable activities for new team members or individuals.                                                                            |                                                                                              |
|Team affected            |impacts-training         |Identifies issues that affect the Training group.                                                                                                             |                                                                                              |
|Team affected            |impacts-rpcr             |Identifies issues that affect the Rackspace-supported Red Hat OpenStack Platform team.                                                                        |                                                                                              |
|Severity                 |sev-1                    |Severity 1 issues are catastrophic issues that has a debilitating impact on product stability or the ability of the user to use the product                   |Compute component stops responding                                                            |
|Severity                 |sev-2                    |Severity 2 issues affects major components and or stability of the product but a workaround does exist to alleviate the impact of the bug                     |API response is slow causing intermittent timeouts                                            |
|Severity                 |sev-3                    |Severity 3 are minor issues with the product that are cosmetic in nature or cause limited tangible impact.                                                    |Typographical errors.                                                                         |
|Origin                   |orig-dev                 |Bugs logged by Devs during the development process or originating in the Dev pipeline by means of automated gating                                            |A component failure found during Dev testing individual changes                               |
|Origin                   |orig-qe                  |Bugs logged by QE during the testing cycle or originating in the QE pipeline by means of automated gating                                                     |Bugs logged during system testing                                                             |
|Origin                   |orig-support             |Bugs logged by the Support team during deployment of the code signed off by QE. This shall be considered as a gap by QE                                       |Inconsistency when deploying packages using a signed-off build                                |
|Origin                   |orig-customer            |Bugs reported by end customer on the RPC product configuration rolled out to them                                                                             |                                                                                              |
|Type                     |type-functional          |Code issue where the functionality is broken                                                                                                                  |                                                                                              |
|Type                     |type-deployment          |Deployment bug where the error is in either the playbook or issues found during deployment                                                                    |                                                                                              |
|Type                     |type-environment         |Non–availability of environment or mis-configuration of an environment                                                                                        |                                                                                              |
|Type                     |type-automation          |Buggy QE code where the gate failure is due to incorrect automation as opposed to a true bug in the system                                                    |                                                                                              |
|Type                     |type-performance         |Bug around a particular build failing the performance baseline                                                                                                |                                                                                              |
|Component                |comp-compute             |Compute related issue                                                                                                                                         |                                                                                              |
|Component                |comp-neutron             |Neutron related issue                                                                                                                                         |                                                                                              |
|Component                |comp-identity            |Identity related issue                                                                                                                                        |                                                                                              |
|Component                |comp-uncategorized       |Generic label so that the said issue can be revisited and the component name added                                                                            |                                                                                              |
|Workflow status (Waffle) |status-approved          |An issue that has been moved into the column Approved.                                                                                                        |                                                                                              |
|Workflow status (Waffle) |status-doing             |An issue that has been moved into the column Doing.                                                                                                           |                                                                                              |
|Workflow status (Waffle) |status-needs-review      |An issue that has been moved into the column Needs-review.                                                                                                    |                                                                                              |
|Workflow status (Waffle) |status-pending-sha-update|An issue that has been moved into the column Pending-SHA-update.                                                                                              |                                                                                              |
|Workflow status          |status-needs-information |The issue requires further information to enable it to be completed.                                                                                          |                                                                                              |
|Workflow status          |status-blocked           |Indicates an issue is blocked on another item of work. The description should be updated with a link to the blocking issue.                                   |                                                                                              |
|Workflow status          |status-dont-merge        |Indicates an issue in Needs-review that should not be merged, generally this indicates the assignee is working on updating the pull request.                  |                                                                                              |
|Workflow status          |status-duplicate         |Any issue that duplicates an existing issue.                                                                                                                  |                                                                                              |
|Workflow status          |status-invalid           |Any issue that is not within scope of the project.                                                                                                            |                                                                                              |
|Workflow status          |status-wontfix           |Any issue that it is determined will not be fixed.                                                                                                            |                                                                                              |
|Workflow status          |status-abandoned         |Any issue that becomes WIP but is closed without being completed.                                                                                             |                                                                                              |
|Tracking upstream project|tracking-upstream        |For tracking issues with upstream projects that are affecting the RPCO project.                                                                               |                                                                                              |
|Product feature          |feature-gating           |Gating-related work.                                                                                                                                          |                                                                                              |
|Product feature          |feature-upgrades         |Upgrades-related work.                                                                                                                                        |                                                                                              |
|Product feature          |feature-monitoring       |Monitoring-related work.                                                                                                                                      |                                                                                              |
|Product feature          |feature-osa              |OSA-related work.                                                                                                                                             |                                                                                              |
|Swim lane                |swimlane-rr              |Issues that form part of the WIP for revision (patch) releases.                                                                                               |                                                                                              |
|Swim lane                |swimlane-enhancements    |Issues that form part of the WIP for major/minor releases.                                                                                                    |                                                                                              |
|Swim lane                |swimlane-improvements    |Issues that form part of the WIP for infrastructure that supports releases.                                                                                   |Gating or this process documentation.                                                         |
|Swim lane                |swimlane-misc            |Issues that form part of the WIP that cannot be categorised by one of the other swim lanes.                                                                   |Spikes.                                                                                       |

## Pre-Backlog -> Backlog
### Adding an issue to the backlog
Click [here](https://github.com/rcbops/rpc-openstack/issues/new) to load the form used when creating a new issue in the backlog. The form is generated from [this template](.github/ISSUE_TEMPLATE.md) which includes a set of questions for the reporter and a checklist to be completed by the owner as the issue is worked. Currently Waffle does not support the use of an issue template and so issues should not be created directly in Waffle.

## Backlog
All issues that are are not approved to be worked are listed in Backlog, this includes new issues and those that have been triaged but not yet committed to.

### Issue triage
Issue triage is an ongoing process that should happen whenever Approved needs updating with new tasks. The engineering team will triage new issues and monitor unprioritised issues so that new commitments are always targetting the most import work.

Each issue is given a priority and that priority is used to help decide the order in which issues are worked. It is important to remember that there is a finite resource available to fix issues. The process of prioritisation is used to focus the available resources on the most important tasks identified.

Issues are labelled with a priority as defined in the [labels table](#Labels).

#### Expedited issues
Expedited issues are allowed to exceed the WIP limit on any column. These issues are critical to fix and must be prioritised above all other work. They are identified with the label 'prio-expedited'. Due to the negative impact expedited issues have on WIP it is important they are used appropriately.

#### Enhancements
Issues labeled as 'type-enhancement-large' or 'type-enhancement-medium' filter into planning for major and minor releases. Tracking of that work is done elsewhere and so these issues should be closed once their information has been transferred to the appropriate place.

Issues labeled as 'type-enhancement-small' should also be given a priority, in general they should be labeled as 'prio-3' but a higher priority can be given if the enhancement helps to prevent customer downtime.

#### Classifying issues
Issues are categorised to simplify the process of identifying the highest priority issues and allow different types of work to be tracked. The steps taken to correctly label an issue are:
* Label issue type
  * Assign the appropriate issue-type label.
  * If the issue is determined to be 'type-undecided', also add the labels 'prio-undecided' and 'status-needs-information'. Add a comment detailing the required information.
  * If the issue is determined to be 'type-enhancement', the issue should be logged as an idea on the [product roadmap](https://trello.com/b/OdRe9RxX/rpc-engineering-roadmap) and closed here with a link to the roadmap card.
  * If the issue is determined to be 'type-bug', add the relevant bug label meta data to the issue being logged
* Identify the teams impacted by the issue
  Any labels relevant to this step will start with 'impacts-'.
  * If an issue is reported by support or they update an existing issue to say they are impacted add the label 'impacts-support'.
  * If an issue is reported by QE, they update an existing issue to say they are impacted or someone else discovers an issue that affects a release candidate add the label 'impacts-qe'.
* Identify the product features impacted by the issue.
  Any labels relevant to this section will start with 'feature-'.
* Identify the severity of the issue based on its impact on the stability and/or functionality on the product or end customer
  * This is a MANDATORY field when logging a bug. 
  * Any labels relevant to this section will start with 'sev-'.
* Identify the origin of the issue based on where the issue is found. Whether it is Dev, QE, Support or reported by end customer
  * This is a MANDATORY field when logging a bug. 
  * Any labels relevant to this section will start with 'orig-'.
* Identify the type of the issue being reported. Whether it is functional, deployment, environmental, automation or performance related
  * This is an OPTIONAL field when logging a bug but should be updated at a later stage once the triage is complete. 
  * Any labels relevant to this section will start with 'type-'.      
Identify the component that is impacted by the issue. This can be Compute, Neutron, Identity etc.
  * This is an OPTIONAL field when logging a bug but should be updated at a later stage once the triage is complete. 
  * Any labels relevant to this section will start with 'comp-'.
* Confirm the issue is valid
  * If the issue is invalid add the label 'status-invalid' and close the issue with a comment detailing why the issue is invalid.
* Confirm the issue is something that will be fixed
  * If the issue is not going to be fixed add the label 'status-wontfix' and close it with a comment explaining why.
* Confirm the issue hasn't previously been logged
  * If there is a pre-existing issue add the label 'status-duplicate' to this new one and close it with a comment linking to the pre-existing issue.
* Determine if the issue is blocked by something
  * If the issue is blocked by some other activity add the label 'status-blocked' and add details of the blocker to the issue description.
* Prioritise the issue if 'type-bug' or 'type-enhancement-small'
  * If there is insufficient information from which to determine the priority add the labels 'prio-undecided' and 'status-needs-information'. Also add a comment detailing the missing information.
  * Assign the appropriate priority label based on the definitions of each priority category, if the issue is labeled with 'type-enhancement-small' generally this will be 'prio-3'.

#### Triage meetings
Triage meetings are held on a weekly basis, with ad hoc meetings held as required. Their main purpose is to review what has been achieved since the last meeting and provide an opportunity to discuss specific cards if there is concern about their current priority. The Waffle board is used to provide this information.

##### Triage meeting tasks
* Review tasks completed since the last meeting
* Review new issues in the backlog
* Allow the opportunity to discuss the classification of any open issue that has not already been discussed in the meeting, this should not be used as a chance to rehash old arguments but instead to highlight the case for issues where the circumstances have changed.

## Backlog -> Approved
Approved is updated with tasks from Backlog if the relevant swim lane in Approved is under its minimum WIP limit. Any new issues in Backlog must be triaged before moving new work to Approved. In general, the next work to commit to should be based on the priorities of support unless there is an issue blocking the engineering team from meeting their responsibilities. If all things are equal the next card to move to Approved should be decided based on priority and age, with the oldest card of the highest priority the next moved.

## Approved
This column shows the work to which the engineering team has currently committed but not yet started.

## Approved -> Doing
### Selecting an issue to work on
Working on a task means moving it from Approved to Doing, this operation is only allowed if it doesn't violate the Doing WIP limit for the relevant swim lane. All available work is found on the Waffle board in Approved, the next task is always at the top. Assign yourself as the owner of the issue at the top and move it from the top of Approved to the bottom of Doing.

If a task includes an existing pull request from someone outside the engineering team, they should not be assigned as the owner. All work must be owned by the engineering team, if someone on another team e.g. support has provided code then work with them to get it merged but ultimately it is the responsibility of the engineering team to manage the flow of work and ensure all aspects of a card are completed.

## Doing
#### Fixing an issue
The issue description contains a list of the steps required to close an issue, this is added by the [issue template](.github/ISSUE_TEMPLATE.md). As each step is completed, update the description.

##### New issues discovered while working an issue
If a new bug or feature requirement is found while working on an assigned issue, that new work item should be logged as a separate issue in Backlog.

If the new issue blocks the existing issue, you should assign yourself to the new issue and move it to Doing - make sure to go through the normal labeling process so the issue is correctly classified and add the appropriate swim lane label. The existing issue should be updated with all the work that has been done, the label 'status-blocked' added and a link to the blocking issue should be included in the issue description. In this situation the WIP limit can be exceeded. Removing blocks to WIP should be considered a high priority, when WIP is blocked the assignee should look to raise this with the team so that the blockage can be removed quickly.

If the new issue does not prevent the resolution of your current task it will be treated as any new issue.

##### Creating a pull request
If an issue affects multiple branches the owner should always start by creating a pull request for the newest branch, generally this means master. Only one pull request should ever be in progress for a task in Doing.

To ensure that issues and pull request are correctly associated, reference the issue at the end of the commit message, e.g.:
    Connected https://github.com/rcbops/rpc-openstack/issues/0

## Doing -> Needs review
A card can only be moved from Doing to Needs-review if Needs-review is below its WIP limit for the relevant swim lane. If that condition is met and you are ready for feedback on your pull request, move the card (this should be a connected pair of the issue and pull request) to the bottom of Needs-review.

## Needs review
Reviewers should always review the tasks in the order the are listed in Needs-review. If owners need to make changes to the pull request, for example base on feedback from reviewers, the task should remain in Needs-review while that is done but the label 'status-dont-merge' should be added to the issue to prevent it being merged prematurely and then removed once the update has been made. The reviewer merging the commit should delete the issue branch (using the link on the pull request page) and tick the issue checklist for the fixed branch.

##### Backports
The owner is responsible for backporting the commit. Backports are done while the card is in Needs-review.

## Needs review -> Pending SHA update
### Issues tracking upstream changes
If the issue relates to a change that has been made upstream, these should be identifiable by the label 'tracking-upstream', and RPCO cannot consume the change until the appropriate SHA's have been updated in RPCO or upstream in OSA, the issue should be moved to the bottom of Pending-SHA-update. This column does not have a WIP limit and is used as a buffer to prevent Needs-review being blocked by WIP that is waiting on a periodic task.

## Needs review -> Done
### Closing the issue
An issue must only be moved to Done if the issue description fields, generated by the issue template, have all been completed. There is no WIP limit on Done :)

## Pending SHA update -> Done
### Closing the issue
In general SHA updates in RPCO are done every two weeks. Once the update is merged, the issues in Pending-SHA-update that are resolved by the update, should be moved to Done.

## Done
Work that has been completed in the last seven days is listed here. After that time it is archived.

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
### Fixing a bug

1. After the bug is triaged and prioritised, make the required changes. New features, breaking changes and other patches of note must include a release note generated using the `reno` tool. Please see `Release Notes` for more information.
2. Push changes directly to a branch on ```rpc-openstack``` in the ```rcbops``` github namespace (rather than a developer's own fork). A pull request is then made from this branch to the ```master``` branch.
3. Unless a bug is specific to a release branch (e.g. ```liberty-12.1```), commit fixes to the ```master``` branch before any potential backports.
4. Bugs meeting backport criteria are backported to the release branches (e.g. ```liberty-12.1```) as appropriate.
5. Github markdown is used to update the original issue with a checklist for tracking which branches have fixes merged.
6. Each time a PR is merged, the associated branch is deleted from ```rpc-openstack```.
7. When all PRs are completed the issue is then closed.

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
* The last line of the commit should be a reference to the issue being fixed using the keyword 'Connected', e.g.
```
Connected https://github.com/rcbops/rpc-openstack/issues/0
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
 * Use GitHub's [pull request reviews](https://help.github.com/articles/about-pull-request-reviews/) function so that your comments are collated into a single review.
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

