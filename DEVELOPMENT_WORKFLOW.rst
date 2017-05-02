====================================
 RPC OpenStack Development Workflow
====================================

Summary
=======

It is currently necessary, to change the way the RPC OpenStack team develops
the project (i.e., adds features, fixes bugs). The old workflow is described
in the :ref:`Old Workflow <old-workflow>` section.

The new workflow is outlined under :ref:`Proposed Workflow
<proposed-workflow>`

.. _old-workflow:

RPC OpenStack's Old Workflow
============================

Facts
-----

#. |rpcos| is configured with the following branches:

   - ``master``

   - ``kilo``

   When we decide to support liberty, a third branch will appear - ``liberty``.

#. Bug fixes move from ``master`` to the other branch(es) via cherry-picks.

#. Bugs are hand-managed by developers. Backport pull requests are submitted
   and merged and the original bug is often not updated in a timely manner.

#. Developers cannot use GitHub's commit message syntax to auto-close bugs.

#. ``master`` 's current focus is not well defined. (Is it the next minor
   release of the most recent stable branch? Is it the next major release of
   RPC OpenStack?)

Workflow
--------

#. A bug is filed or a feature is proposed to |rpcos|

#. After triage and prioritization, a developer creates a fix.

#. The fix is pushed to a branch on that developer's fork.

   This prevents another developer from being able to collaborate on that
   change (unless they're given access to that repository).

#. The developer submits a pull request against ``master``. It's reviewed,
   iterated upon, and eventually merged.

#. If that PR is elligible to be backported, then the associated bug is
   labeled as such and PRs are submitted to the stable branches.

#. Stable PRs are then reviewed and merged.

#. A developer will (eventually) close the original issue.

.. _proposed-workflow:

RPC OpenStack's Proposed New Workflow
=====================================

Pre-Workflow
------------

#. Add documentation to ``master`` that is easily discoverable detailing the
   current development focus for ``master``.

Workflow
--------

#. After a bug or feature is prioritized and assigned, the developer pushes a
   fix to a branch on |rpcos|. [#]_

#. A PR is created from the branch on |rpcos|, reviewed, iterated upon and
   eventually merged.

#. Bugs meeting backport criteria [#]_ are backported to the previous branches
   as appropriate.

#. Backport PRs are added to the original issue by the developers who create
   them for easier tracking.

   .. code::

       {{ Issue Description }}

       ----

       - [ ] Original PR: https://github.com/rcbops/rpc-openstack/pull/{{number}}

       - [ ] Backport to kilo: https://github.com/rcbpos/...

       - [ ] ...

   Using markdown checklists in GitHub will give others a quick view into the
   status of each pull request while viewing all issues as well as the
   individual issue.

#. Each time a PR is merged, the associated branch is deleted from |rpcos|.

   The task on the original issue should also be marked as completed.

#. When all PRs are completed the issue is then closed by a developer.

----

.. Replacements

.. |rpcos| replace:: ``rcbops/rpc-openstack``
.. |lsbnext| replace:: ``{{latest-stable-branch-codename}}``

.. Footnotes

.. [#]
    It is suggested that developers use succinct branch names, e.g.,
    ``bug/103`` or ``feature/210``, which are descriptive but also point at
    the item being worked on. Backport PRs might consider branch names like
    ``bug/{{backport-branch}}/103`` (e.g., ``bug/kilo/103``).

.. [#]
    This document suggests using
    http://docs.openstack.org/project-team-guide/stable-branches.html as a
    basis for these backport criteria or creating our own *well-documented*
    criteria based on the linked criteria.

.. Metadata

:author: Ian Cordasco
:Created At: 2015-12-10
:Last Modified By: Ian Cordasco
:Last Modified At: 2015-12-17
