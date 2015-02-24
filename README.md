build crossby
=============

This is an attempt at creating an _GNU Make_-based environment for
reliably building libraries and executables from the same source code
for multiple platforms. Building everything from source should be as
easy as running a single `make` command. New source packages can be
defined using a handful of definitions; everything beyond that is
generated from templates.

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

Usage
-----

Typing `make` gives a list of targets that can be run and outputs the
configuration.

Those are controlled by a number of variables which can be passed via
the command line.

### Variables

- `ROOT` points to the top-level directory where all
information about the build are stored. Default: Current working
directory.

- `PROJECT` determines which project should be built. The main
configuration file (`$ROOT/$PROJECT.mk`) is determined using this
variable. Default: `default` (so the default configuration file is
`default.mk` in the current working directory).

- `PACKAGES` contains a list of packages that should be built. For
every package, Makefile snippet `package/$PKG.mk` is included which
describes how to fetch and build the package. If `PACKAGES` is not
specified, all `*.mk` files in `$ROOT/pacakge` subdirectory are
included.

- `ARCHS` contains a list of architectures for which every
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
  `build/$PKG/$ARCH/`
- `target` is the top installation directory

Configuration
-------------

### Add, edit, remove source packages

- `pkg_VERSION`
- `pkg_URL`
- `pkg_POSTUNPACK`: Command that should be run after unpacking
- `pkg_BUiLDSYSTEM`: The buildsystem used by this package.
- `pkg_BUILDFLAGS`: Extra build flags that are passed to the buildsystem
- `pkg_CFLAGS`, `pkg_$ARCH_CFLAGS`: CFLAGS variable (general,
  architecture-specific) for this package
- `pkg_SUFFIX`: archive file format for this package
- `pkg_NAMESPACE`: (specific to the `go` buildsystem): Namespace into
  which the package is installed.
- `pkg_ARCHS`: Limits the architectures for which this package can be built

Extending
---------

To add new buildsystems, the following functions (shell variables)
must be implemented:

- `buildsys_UNPACK`
- `buildsys_BUILD`
- `buildsys_INSTALL`

License
-------

Copyright (C) 2015  Hilko Bengen <bengen@hilluzination.de>

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
