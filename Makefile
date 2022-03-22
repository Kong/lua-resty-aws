.PHONY: docs install dev clean test pack

# specify VERSION as 'x.y.z' or 'dev'
target_rock := lua-resty-aws-${VERSION}-1.src.rock

install:
	if [ ! -d "src/resty/aws/raw-api" ]; then \
		bash ./update_api_files.sh; \
	fi
	luarocks make

dev:
	bash ./update_api_files.sh

test:
	luacheck .
	busted

docs:
	mv docs/ldoc.css ./
	-@rm -rf docs
	mkdir docs
	mv ldoc.css docs/
	ldoc .

clean:
	-@rm lua-resty-aws-dev-1.rockspec
	-@rm *.rock
	-@rm -rf delete-me
	-@rm -rf src/resty/aws/raw-api

$(target_rock):
	[ -n "$$VERSION" ] || { echo VERSION not set; exit 1; }
	-@rm -rf /tmp/random_dir_2cs4f0tghRT
	mkdir /tmp/random_dir_2cs4f0tghRT
	cd /tmp/random_dir_2cs4f0tghRT; git clone https://github.com/kong/lua-resty-aws.git
	cd /tmp/random_dir_2cs4f0tghRT/lua-resty-aws; if [ ! "${VERSION}" = "dev" ]; then git checkout ${VERSION}; fi
	cd /tmp/random_dir_2cs4f0tghRT/lua-resty-aws; make dev
	cd /tmp/random_dir_2cs4f0tghRT; zip -r lua-resty-aws-${VERSION}-1.src.rock lua-resty-aws
	cd /tmp/random_dir_2cs4f0tghRT; cat lua-resty-aws/lua-resty-aws-dev-1.rockspec | sed "s/package_version = \"dev\"/package_version = \"${VERSION}\"/" > lua-resty-aws-${VERSION}-1.rockspec
	cd /tmp/random_dir_2cs4f0tghRT; zip -r lua-resty-aws-${VERSION}-1.src.rock lua-resty-aws-${VERSION}-1.rockspec
	mv /tmp/random_dir_2cs4f0tghRT/lua-resty-aws-${VERSION}-1.src.rock ./
	-@rm lua-resty-aws-${VERSION}-1.rockspec
	mv /tmp/random_dir_2cs4f0tghRT/lua-resty-aws-${VERSION}-1.rockspec ./

pack: $(target_rock)

upload: $(target_rock)
	[ -n "$$VERSION" ] || { echo VERSION not set; exit 1; }
	[ -n "$$APIKEY" ] || { echo APIKEY not set, should contain the LuaRocks api-key for uploads ; exit 1; }
	./upload.sh ${VERSION} ${APIKEY}
