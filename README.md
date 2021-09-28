[![ci](https://github.com/alexhumphreys/hello-idris2/actions/workflows/ci.yml/badge.svg)](https://github.com/alexhumphreys/hello-idris2/actions/workflows/ci.yml)

# Verpackung

Very naive attempt at a package set. Basically just grabbing the latest of a list repos and running `idris2 --build` on them and seeing if they compile, then outputting a list of what passed and failed.

See the `./package-set/packages.dhall` for the list of packages, and `./package-set/$SomeDate` dir for what passed and failed.

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

## Acknowledgments

The `/Verpackung/Derive` dir is from @ShinKage et al's work on the idris2-lsp.
