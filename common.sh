ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
grep -q "release 7" /etc/redhat-release && R7=1 || R7=0
echo "ROOT:$ROOT"
echo "CPUS:$CPUS"
echo "VERS:$R7"
