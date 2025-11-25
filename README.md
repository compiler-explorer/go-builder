### Go Compiler build scripts

The repository is part of the [Compiler Explorer](https://godbolt.org/) project. It builds
the docker images used to build the various Go compilers used on the site.

## Testing locally

`sudo docker build -t builder .`

`sudo docker run --rm -v/tmp/out:/build builder ./build.sh trunk /build`
