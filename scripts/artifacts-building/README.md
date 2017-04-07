What's happening here
=====================

On PR
-----

On PR, we are only building artifacts to see if the process is fine.
It means running these jobs:

* Building apt
* Building git
* Building Python
* Building containers

in a parallel way. In these jobs, we don't push to mirror. These
are merely for testing.

On regular time intervals
-------------------------

A periodic job ensures the complete building of all artifacts.
This job is composed of multiple steps in a serial way.

Each step of the process results in an upload if there is no
existing artifact for this version (PUSH_TO_MIRROR: yes in
the CI job)

The steps are:

1. Building apt
1. Building git
1. Building Python
1. Building containers

On a new tag
------------

New tag is a specific case of periodic.
After a new tag, a periodic job should be manually triggered.
Because PUSH_TO_MIRROR is set to YES in periodics, it will
automatically push the new version of the artifacts after
sucessful building!
