.PHONY: bootstrap diagnostics simulator test run ipa clean

bootstrap:
	./scripts/bootstrap.sh

diagnostics:
	./scripts/print_diagnostics.sh

simulator:
	./scripts/build_simulator.sh

test:
	./scripts/test.sh

run:
	./scripts/run_simulator.sh

ipa:
	./scripts/build_unsigned_ipa.sh

clean:
	rm -rf Build Artifacts DavLauncher.xcodeproj
