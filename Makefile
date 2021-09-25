repl:
	rlwrap idris2 Verpackung/Main.idr

edit-tests1:
	cd ./tests/verpackung/test001 && rlwrap idris2 -p verpackung Main.idr

edit-tests2:
	cd ./tests/verpackung/test002 && rlwrap idris2 -p verpackung Greet.idr

clean:
	rm -f tests/*.idr~
	rm -f tests/*.ibc
	rm -f Idrall/*.idr~
	rm -f Idrall/*.ibc
	rm -rf build/
	rm -rf tests/build/

.PHONY: build
build:
	idris2 --build verpackung.ipkg --cg node
	echo '#!/usr/bin/env node' | cat - build/exec/verpackung > temp && mv temp build/exec/verpackung
	chmod +x build/exec/verpackung

# this step is covered by `make build` if have set `main` and `executable` set in the `.ipkg` file.
# build-executable: build # Has a dependency on build, not sure why
# idris2 ./Verpackung/Main.idr -o verpackung --cg node # this is the name of the executable
# chmod +x build/exec/verpackung
# it will be created in ./build/exec/

run-executable: # build-executable
	./build/exec/verpackung

install:
	idris2 --install verpackung.ipkg

testbin:
	@${MAKE} -C tests testbin

# run like: `make test only=test002`
test-only:
	${MAKE} -C tests only=$(only)

# only run the tests that fail during the last run
retest-only:
	${MAKE} -C tests retest

test: build install testbin test-only
retest: build install testbin retest-only

time-time:
	time ${MAKE} test INTERACTIVE=''

docs:
	idris2 --mkdoc helloidris2.ipkg

docker-build:
	docker build . -t snazzybucket/hello-idris2

docker-run:
	docker run snazzybucket/hello-idris2
