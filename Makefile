build: install
	grunt

install:
	npm install
	./node_modules/.bin/bower install

watch:
	watch --color -n 1 make build

serve:
	python -m SimpleHTTPServer 1893

.PHONY: build