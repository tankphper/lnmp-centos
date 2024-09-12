ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
grep -q "release 7" /etc/redhat-release && VERS=7 || VERS=0
grep -q "release 8" /etc/redhat-release && VERS=8
grep -q "release 9" /etc/redhat-release && VERS=9
echo "ROOT:$ROOT"
echo "CPUS:$CPUS"
echo "VERS:$VERS"

# V1 > V2
function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
# V1 >= V2
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
# V1 <= V2
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
# V1 < V2
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
