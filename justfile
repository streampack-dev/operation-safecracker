maven := `if command -v mvnd >/dev/null 2>&1; then printf '%s' mvnd; else printf '%s' ./mvnw; fi`

default:
    just --list

clean:
    {{maven}} clean

# Build the jar without tests
build: clean
    {{maven}} -DskipTests=true package

# Build the jar with tests
test: clean
    {{maven}} package
