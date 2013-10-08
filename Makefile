build:
	./node_modules/.bin/apps-b . ./build/

watch:
	watch -n 1 -c ./node_modules/.bin/apps-b . ./build/

test:
	./node_modules/.bin/mocha --compilers coffee:coffee-script --reporter spec --ui exports --bail

serve:
	python -m SimpleHTTPServer 6200

.PHONY: build test