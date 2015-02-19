build crossby
=============

This is an attempt at creating an _GNU Make_-based environment for
reliably building libraries and executables from the same source code
for multiple platforms. Building everything from source should be as
easy as running a single `make` command.

Currently supported target platforms are i386, x86_64 for Linux-based
and MS Windows-based systems. Currently supported build systems are
Autoconf/Automake (`configure/make/make install`) and Go (`go build/go
install`). It should be easy to extend the system in both aspects --
this is what I initially needed.

Assumptions
-----------

- Self-contained, statically linked executables that are easy to
  distribute should be produced in a reliable fashion. Package
  management and upgrades are beyond the scope of this project.

- Source code is readily available for automated download via the
  network (i.e. tarballs from git commits by tag, branch, or hash),
  but it should be cached locally.

- Even though make has a reputation for quirky syntax, its general
  approach based upon targets, prerequisites, recipies should be
  leveraged.

- Building the cross-toolchains is a problem that has been solved --
  the task does not need to be repeated as part of this project.

Configure
---------

### TODO: Add, edit, remove source packages

### TODO: Manage architectures

Eextend
-------

### TODO: Add build systems

Author
------

Hilko Bengen <bengen@hilluzination.de>
