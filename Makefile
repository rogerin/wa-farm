.PHONY: setup create status stop heartbeat test help

help:
	@./wa-farm.sh --help

setup:
	./wa-farm.sh setup

create:
	./wa-farm.sh create all

status:
	./wa-farm.sh status

stop:
	./wa-farm.sh stop all

heartbeat:
	./wa-farm.sh heartbeat

test:
	bash -n ./wa-farm.sh
	./wa-farm.sh --version
	./wa-farm.sh status
