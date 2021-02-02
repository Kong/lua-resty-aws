.PHONY: docs install dev clean test

install:
	if [ ! -d "src/resty/aws/raw-api" ]; then \
		bash ./update_api_files.sh; \
	fi
	luarocks make

dev:
	bash ./update_api_files.sh

test:
	busted

docs:
	mv docs/ldoc.css ./
	-@rm -rf docs
	mkdir docs
	mv ldoc.css docs/
	ldoc .

clean:
	-@rm lua-resty-aws-dev-1.rockspec
	-@rm -rf delete-me
	-@rm -rf src/resty/aws/raw-api

