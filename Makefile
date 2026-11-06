APP := dist/Eyes Protecter.app

.PHONY: all app open clean

all: app

app:
	./scripts/build-app.sh

open: app
	open "$(APP)"

clean:
	rm -rf .build dist
