================================
 RPC OpenStack Release Workflow
================================

Summary
=======

It is currently necessary, to change the way the RPC OpenStack team releases
the project (i.e., branching, tagging, etc.). The old workflow is described
below and the proposed new workflow is described below the old workflow.

.. _old-workflow:

RPC OpenStack's Old Workflow
============================

.. note::
    This section is a bit unclear to me even now. It will need refinement.

#. When targetted features, bugs, etc. are merged to the appropriate branch, a
   Release Candidate (RC) tag is created, e.g., ``r11.0.0rc1`` and a branch is
   created.

#. Our QE and Support teams use that tag to test certain scenarios.

#. We receive feedback and bug reports which are fixed. We then go back to
   Step 1 until we have a version with which everyone is the least unhappy.
   The most recent RC tag is also then the final tag, e.g., ``r11.0.0``.

Our official release document (hidden away in a private wiki) states we should
create a branch for a release before it is created, but recently when we
released ``r11.1.0``, we created a separate branch ``kilo-11.1`` after we
decided on the final acceptable ``r11.1.0`` RC tag.

.. _proposed-workflow:

RPC OpenStack's Proposed New Workflow
=====================================

.. note::

    This proposed release workflow is meant to mimic some of OpenStack's
    practices.

Pre-Workflow
------------

Decisions need to be made around distinctions for major, minor, and
patch-level releases. Here are some suggested distinctions:

Major, e.g., ``r11.0.0``, ``r12.0.0``, etc.

    A major release should only include changes necessary to release the next
    version of OpenStack. No new features should be included in this version
    from |rpcos|. New versions may be included (as a matter of course) from
    OpenStack Ansible.

Minor, e.g., ``r11.1.0``, ``r11.2.0``, etc.

    A minor release should include new features added to |rpcos|. A minor
    release will also include bug fixes.

Patch, e.g., ``r11.0.1``, ``r11.0.2``, ``r11.1.1``, etc.

    A patch release should only include bug fixes that should have no upgrade
    impatch from patch release to patch release. SHA bumps of OpenStack
    services or OpenStack Ansible should be made sparingly in patch releases.
    Ideally, they should only happen when stakeholders downstream of |rpcos|
    request them.

Workflow
--------

#. Each time a large feature targetted for the next minor release is merged, a
   Beta tag is created, e.g., ``r11.1.0b1``, ``r11.1.0b2``, etc.

#. As we approach the end of features and bugs targetted for a minor release,
   we create a Release Candidate tag, e.g., ``r11.1.0rc1``.

#. Each tag that is created should be tested in depth by QE and/or Support for
   acceptance and confirmation that the acceptance criteria were met. **This
   is designed to create shorter feedback loops.**

#. As bugs are identified in these tags, work is merged to the target branch.

#. When an rc tag is identified as the final release candidate and a final tag
   is created, e.g., ``r11.1.0`` a branch may potentially be created from that
   tag.

----

.. Replacements

.. |rpcos| replace:: ``rcbops/rpc-openstack``

.. Metadata

:author: Ian Cordasco
:Created At: 2015-12-17
:Last Modified By: Ian Cordasco
:Last Modified At: 2015-12-17
