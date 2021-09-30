[![ci](https://github.com/alexhumphreys/hello-idris2/actions/workflows/ci.yml/badge.svg)](https://github.com/alexhumphreys/hello-idris2/actions/workflows/ci.yml)

# Verpackung

Very naive attempt at a package set. Basically just grabbing the latest of a list repos and running `idris2 --build` on them and seeing if they compile, then outputting a list of what passed and failed.

See the [`./package-set/packages.dhall`](https://github.com/alexhumphreys/verpackung/blob/main/package-set/packages.dhall) for the list of packages, and `./package-set/$SomeDate` dir for what passed and failed.

## Adding a package

Open a PR and add it to the list in [`./package-set/packages.dhall`](https://github.com/alexhumphreys/verpackung/blob/main/package-set/packages.dhall). Be sure to add it after all the packages it depends on, this list isn't very clever (See the "Note on dependencies" below).

## Running

To build this project, run:

```
make build
```

To test this project, run:

```
make test
```

To create and run an executable, run:

```
make run-executable
```

There's some other `make` tasks for editing files (using `rlwrap` to make the repl behave better), and for docker and documentation. Take a look to see.

## Note on dependencies

I think right now, if a PackageA depends on PackageB, and PackageB depends on PackageC, then the `depends` field in PackageA's `.ipkg` file will need to list both `PackageB` and `PackageC`.

Right now this package set isn't very clever, so it's basically just building packages in the order it finds them in `packages.dhall`. So I think this'll work for now as packages must specify their transitive dependencies and the list is small. As it grows I imagine it'll need a smarter way to work out dependencies, and which order to build them in.

## Acknowledgments

The `/Verpackung/Derive` dir is from @ShinKage et al's work on the idris2-lsp.
