build:
	./node_modules/.bin/apps-b . ./build/

watch:
	watch -n 1 -c ./node_modules/.bin/apps-b . ./build/

serve:
	python -m SimpleHTTPServer 6200

.PHONY: build