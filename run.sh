#!/usr/bin/env bash
# Upgrades the service from Spring Boot 3.5 to 4.0 with OpenRewrite, then compares the API with
# the golden responses of the 3.5 version at every step. The summary is compared with expected.txt.
# Exit code 1 if the result differs.
set -euo pipefail
cd "$(dirname "$0")"

for tool in mvn curl jq; do
    command -v "$tool" >/dev/null || { echo "FAIL: $tool is required, see README.md" >&2; exit 1; }
done
# On a newer JDK the recipe cannot parse the sources, skips them and still reports BUILD SUCCESS
[[ $(mvn -v) == *"Java version: 21."* ]] || { echo "FAIL: Maven must run on JDK 21, see README.md" >&2; exit 1; }

PLUGIN=org.openrewrite.maven:rewrite-maven-plugin:6.46.1
RECIPES=org.openrewrite.recipe:rewrite-spring:6.37.1
RECIPE=org.openrewrite.java.spring.boot4.UpgradeSpringBoot_4_0

GOLDEN=contract/golden
# Outside the clone on purpose: OpenRewrite skips files ignored by git and still reports BUILD SUCCESS
BUILD=$(mktemp -d)
BOOT3=$BUILD/boot3
BOOT4=$BUILD/boot4
REPORT=$BUILD/report.txt

echo "work directory: $BUILD"
# Build output goes to log files, so a failed step must say where to look
trap 'code=$?; [ "$code" -eq 0 ] || echo "FAIL: exit code $code, logs are in $BUILD" >&2' EXIT

say() {
    echo "$*" | tee -a "$REPORT"
}

# Runs maven goals and reports the result. A red build is a result here, not a reason to stop:
# the contract check is expected to go red, and a broken jar stops the next snapshot anyway.
# Failures include errors. No reports means zero tests: compilation failed.
maven_step() {
    local label=$1 log=$2 dir=$3 result=green tests
    shift 3
    (cd "$dir" && mvn -B -q clean "$@") >"$BUILD/$log.log" 2>&1 || result=red
    tests=$(cat "$dir"/target/surefire-reports/*.txt 2>/dev/null \
        | awk -F'[:,] *' '/^Tests run:/ {r+=$2; f+=$4+$6} END {printf "tests %d, failures %d", r, f}' || true)
    say "$label: $result, $tests"
}

# Compares the responses in a directory with the golden ones using the given command.
# A file missing from either side fails the command, so a response without a golden file counts as a change.
report_changes() {
    local label=$1 out=$2 changed=() total=0 name
    shift 2
    for name in $(ls "$GOLDEN" "$out" | grep '\.txt$' | sort -u); do
        total=$((total + 1))
        "$@" "$GOLDEN/$name" "$out/$name" || changed+=("${name%.txt}")
    done
    say "$label: changed ${#changed[@]} of $total${changed[*]:+ (${changed[*]})}"
}

# Key order does not change a JSON value (RFC 8259), so here bodies are compared with sorted keys.
# The status line is quoted to become a JSON value too. A body that is not JSON counts as a change.
sorted_json() {
    sed 's/^HTTP .*/"&"/' "$1" | jq -S .
}

same_json() {
    local a b
    a=$(sorted_json "$1") && b=$(sorted_json "$2") && [ "$a" = "$b" ]
}

# Captures the contract of a built service and compares it with the golden responses.
snapshot() {
    local label=$1 dir=$2 out=$BUILD/out-$3
    shift 3
    contract/capture.sh "$dir/target/orders-api-1.0.0.jar" "$out" "$@"
    report_changes "$label" "$out" cmp -s
}

# 1. The 3.5 version: the baseline must match the golden responses
cp -R service "$BOOT3"
maven_step "boot 3.5 build" boot3-build "$BOOT3" package
snapshot "boot 3.5 against golden" "$BOOT3" boot3
maven_step "contract check on boot3" boot3-check "$BOOT3" test -Dtest=OrderContractCheck

# 2. The recipe
cp -R service "$BOOT4"
(cd "$BOOT4" && mvn -B "$PLUGIN:run" -Drewrite.recipeArtifactCoordinates="$RECIPES" -Drewrite.activeRecipes="$RECIPE") \
    >"$BUILD/rewrite.log" 2>&1
BOOT_VERSION=$(sed -n '/<parent>/,/<\/parent>/ s/.*<version>\(4\.[0-9.]*\)<\/version>.*/\1/p' "$BOOT4/pom.xml")
if [ -z "$BOOT_VERSION" ]; then
    echo "FAIL: the recipe did not move the parent to Spring Boot 4, see $BUILD/rewrite.log" >&2
    exit 1
fi
say "recipe: parent is now ${BOOT_VERSION%.*}.x"
echo "exact Spring Boot version (not compared): $BOOT_VERSION"
if cmp -s service/src/main/resources/application.properties "$BOOT4/src/main/resources/application.properties"; then
    say "recipe: application.properties untouched"
else
    say "recipe: application.properties changed"
fi

# 3. The build a pipeline would see
maven_step "boot 4.0 build after recipe" boot4-build "$BOOT4" verify

# 4. The contract after the recipe and after each fix
JACKSON2=--spring.jackson.use-jackson2-defaults=true
PROBES=--management.endpoint.health.probes.enabled=false
KEY_ORDER=--spring.jackson.mapper.sort-properties-alphabetically=false
OTHER_JACKSON=(
    --spring.jackson.datatype.enum.write-enums-using-to-string=false
    --spring.jackson.datatype.enum.read-enums-using-to-string=false
    --spring.jackson.deserialization.fail-on-null-for-primitives=false
    --spring.jackson.deserialization.fail-on-trailing-tokens=false
)

snapshot "boot 4.0 after recipe" "$BOOT4" boot4
report_changes "boot 4.0 after recipe, as json" "$BUILD/out-boot4" same_json
snapshot "plus use-jackson2-defaults" "$BOOT4" jackson2 "$JACKSON2"
snapshot "plus probes disabled" "$BOOT4" jackson2-probes "$JACKSON2" "$PROBES"
snapshot "five explicit settings and probes disabled" "$BOOT4" explicit "$KEY_ORDER" "${OTHER_JACKSON[@]}" "$PROBES"

# Control for the json comparison: with everything fixed but the sorting only key order is left
snapshot "only key order left" "$BOOT4" order-only "${OTHER_JACKSON[@]}" "$PROBES"
report_changes "only key order left, as json" "$BUILD/out-order-only" same_json

# 5. A test in the build that pins the exact contract notices the change
maven_step "contract check on boot4" boot4-check "$BOOT4" test -Dtest=OrderContractCheck

if diff -u expected.txt "$REPORT"; then
    echo "OK: the result matches expected.txt"
else
    echo "FAIL: the result differs from expected.txt" >&2
    exit 1
fi
