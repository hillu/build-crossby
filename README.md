Note: Deprecated: Please do not use.
====================================

I have abandoned this project for a number of reasons:

- I have stretched the `$(call $(eval ...))` method of generating
  Makefile rules from templates too far: Debugging the resulting rules
  requires too much knowledge of GNU Make details.

- Generating rules becomes too slow after the number of packages
  exceeds a dozen.

- In my projects, Golang dependencies introduced cycles which can be
  resolved inside the _go_ tool, without having to install object
  files to the target directory.

- With [golang/dep](https://github.com/golang/dep), there is a decent
  approach to dependency management and "vendoring" for pure-Golang
  projects. This only leaves C libraries which can be managed using a
  much simpler Makefile.

- Too many subtle bugs...

build crossby
=============

This is an attempt at creating an _GNU Make_-based environment for
reliably building libraries and executables from the same source code
for multiple platforms. Building everything from source should be as
easy as running a single `make` command. New source packages can be
defined using a handful of definitions; everything beyond that is
generated from templates.

Currently supported target platforms are i386, x86_64 (glibc or musl)
for Linux-based and MS Windows-based systems. Currently supported
build systems are Autoconf/Automake (`configure/make/make install`),
classic Makefiles, and Go (`go build/go install`). It should be easy
to extend the system in both aspects -- this is what I initially
needed.

Assumptions
-----------

- Self-contained, statically linked executables that are easy to
  distribute should be produced in a reliable fashion. Package
  management and upgrades are beyond the scope of this project.

- Source code is readily available for automated download via the
  network (i.e. tarballs from git commits by tag, branch, or hash),
  but it should be cached locally. Tarballs can also be stored in a
  `tarballs/` subdirectory so they can be checked into source control.

- Even though make has a reputation for quirky syntax, its general
  approach based upon targets, prerequisites, recipies should be
  leveraged.

- Building the cross-toolchains is a problem that has generally been
  solved -- the task does not need to be repeated as part of this
  project. An i386- or amd64-based Debian GNU/Linux system can
  generate i386 and amd64 binaries for Linux and Windows.
  Cross-compiling Go libraries using the distribution-provided
  toolchain has its problems because `go install` wants to install the
  standard library into `$GOROOT`, but my inofficial
  `golang-go-cross`[1] package should help with this problem.

[1] https://github.com/hillu/golang-go-cross

Usage
-----

Typing `make` gives a list of targets that can be run and outputs the
configuration.

Those are controlled by a number of variables which can be passed via
the command line.

### Variables

- `BC_ROOT` points to the top-level directory where all
information about the build are stored. Default: Current working
directory.

- `BC_PROJECT` determines which project should be built. The main
configuration file (`$ROOT/$PROJECT.mk`) is determined using this
variable. Default: `default` (so the default configuration file is
`default.mk` in the current working directory).

- `BC_PACKAGES` contains a list of packages that should be built. For
every package, Makefile snippet `package/$PKG.mk` is included which
describes how to fetch and build the package. If `PACKAGES` is not
specified, all `*.mk` files in `$ROOT/pacakge` subdirectory are
included.

- `BC_ARCHS` contains a list of architectures for which every
package should be built. If not set, it defaults to x86 and x86_64
architectures for Linux and Windows.

Before build, the sources can be patched. For this, all *.patch files
in `patches/$PKG/$VERSION` are used.

### Subdirectories

- `package` contains configuration files with information on how to
  fetch and build source packges (`package/$PKG.mk`)
- `cache` is used the downloaded source archives
- `patches` contains package-specific patches
- `build` is used for building packages -- individually below
  `build/$ARCH/$PKG-$VERSION
- `stamps` contains stamp files for GNU Make to track what artifacts
  have been built.
- `target` is the top installation directory

Configuration
-------------

### Add, edit, remove source packages

- `pkg_VERSION`
- `pkg_URL`
- `pkg_POSTUNPACK`: Command that should be run after unpacking
- `pkg_BUILDSYSTEM`: The buildsystem used by this package.
- `pkg_CONFIGFLAGS`: Extra configure flags that are passed to the
  buildsystem
- `pkg_BUILDFLAGS`: Extra build flags that are passed to the buildsystem
- `pkg_CFLAGS`, `pkg_$ARCH_CFLAGS`: CFLAGS variable (general,
  architecture-specific) for this package
- `pkg_SUFFIX`: archive file format (e.g. `.tar.gz`) for this package.
  This is usually not needed because it can be derived from the
  download URL (`pkg_URL`).
- `pkg_NAMESPACE`: (specific to the `go` buildsystem): Namespace into
  which the package is installed.
- `pkg_ARCHS`: Limits the architectures for which this package can be built

Extending
---------

To add new buildsystems, the following Make functions must be
implemented:

- `<buildsys>_UNPACK`
- `<buildsys>_BUILD`
- `<buildsys>_INSTALL`

Similar projects
----------------

- [mulle-bootstrap](http://www.mulle-kybernetik.com/software/git/mulle-bootstrap/)
  is also built on the principle that project dependencies are
  installed into a local subdirectory. It is written as a set of
  portable shell scripts and is mainly designed to work with git or
  Subversion checkouts. Version pinning seems to be supported.

License
-------

Copyright (C) 2015, 2016  Hilko Bengen <bengen@hilluzination.de>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
