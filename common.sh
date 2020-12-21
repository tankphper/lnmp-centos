ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
grep -q "release 7" /etc/redhat-release && VERS=7 || VERS=0
grep -q "release 8" /etc/redhat-release && VERS=8
echo "ROOT:$ROOT"
echo "CPUS:$CPUS"
echo "VERS:$VERS"
