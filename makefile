# project configuration
name := grip
buildDir := build
packages := logging grip # TODO: add other packages when there are tests
projectPath := github.com/tychoish/$(name)

# declaration of dependencies
lintDeps := github.com/alecthomas/gometalinter
testDeps := github.com/stretchr/testify
deps := github.com/coreos/go-systemd/journal

# implementation details for being able to lazily
gopath := $(shell go env GOPATH)
deps := $(addprefix $(gopath)/src/,${deps})
lintDeps := $(addprefix $(gopath)/src/,${lintDeps})
testDeps := $(addprefix $(gopath)/src/,${testDeps})
$(gopath)/src/%:
	go get $(subst $(gopath)/src/,,$@)
# end dependency installation tools


# userfacing targets for basic build/test/lint operations
.PHONY:build test lint coverage-report
build:deps
	@mkdir -p $@
	go build
test:test-deps
	go test -v ./...
levelsRegex := 	(Catch.*|Default.*|Emergency.*|Alert.*|Critical.*|Error.*|Warning.*|Notice.*|Debug.*|Info.*)
lintExclusion := --exclude="exported method Grip\.$(levelsRegex)"
lintExclusion += --exclude="exported function $(levelsRegex)"
lintExclusion += --exclude="exported method InternalSender\..*"
lintExclusion += --exclude="package comment should be of the form \"Package grip \.\.\.\""
lint:
	-$(gopath)/bin/gometalinter --deadline=20s --disable=gotype $(lintExclusion) ./...
coverage:$(foreach target,$(packages),$(buildDir)/coverage.$(target).out)
coverage-report:$(foreach target,$(packages),coverage-report-$(target))
# end front-ends


# implementation details for building the binary and creating a
# convienent link in the working directory
$(gopath)/src/$(projectPath):
	rm -f $@
	mkdir -p `dirname $@`
	ln -s $(shell pwd) $@
$(name):$(buildDir)/$(name)
	[ -L $@ ] || ln -s $< $@
.PHONY:$(buildDir)/$(name)
$(buildDir)/$(name):$(gopath)/src/$(projectPath)
	go build -o $@ main/$(name).go
# end main build


# implementation for package coverage
coverage-%:$(buildDir)/coverage.%.out
coverage-report-%:$(buildDir)/coverage.%.out
	[ -f $< ] && go tool cover -html=$<
$(buildDir)/coverage.%.out:% test-deps
	go test -v -covermode=count -coverprofile=$@ $(projectPath)/$<
	[ -f $@ ] && go tool cover -func=$@ | sed 's%${projectPath}/%%' | column -t
$(buildDir)/coverage.$(name).out:test-deps
	go test -v -covermode=count -coverprofile=$@ $(projectPath)
	[ -f $@ ] && go tool cover -func=$@ | sed 's%${projectPath}/%%' | column -t
# end coverage rports


# targets to install dependencies
deps:$(deps)
test-deps:$(testDeps)
lint-deps:$(lintDeps)
	gometalinter --install
clean:
	rm -rf $(deps) $(lintDeps) $(testDeps)
