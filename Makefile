.PHONY: all index.html

all: index.html

index.html: webxrlayers-1.bs
	curl https://api.csswg.org/bikeshed/ -F file=@webxrlayers-1.bs -F output=err
	curl https://api.csswg.org/bikeshed/ -F file=@webxrlayers-1.bs -F force=1 > index.html | tee
