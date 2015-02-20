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

### Add, edit, remove source packages

The `PACKAGES` variable contains a list of packages that should be
built. For every package, there is a configuration file
package/$PKG.mk which describes how to fetch and build the package.

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

### Manage architectures

The `ARCHS` variable contains a list of architectures for which every
package should be built.

Eextend
-------

To add new buildsystems, the following functions (shell variables)
must be implemented:

- `buildsys_UNPACK`
- `buildsys_BUILD`
- `buildsys_INSTALL`

Author
------

Hilko Bengen <bengen@hilluzination.de>
