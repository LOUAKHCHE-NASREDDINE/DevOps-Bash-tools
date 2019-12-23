#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2019-12-06 11:10:26 +0000 (Fri, 06 Dec 2019)
#
#  https://github.com/harisekhon/bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

# Script to more easily connect to HiveServer2 without having to specify the big JDBC connection string and all options like kerberos principal, ssl etc
#
# Tested on Hive 1.1.0 on CHD 5.10

# useful options for scripting:
#
#   --silent=true
#   --outputformat=tsv2     (tsv is deprecated and single quotes results, tsv2 is recommended and cleaner)
#
# list all databases
#
#   ./beeline.sh --silent=true --outputformat=tsv2 -e 'show databases' | tail -n +2
#
# list all tables in all databases
#
#   opts="--silent=true --outputformat=tsv2"; ./beeline.sh $opts -e 'show databases' | tail -n +2 | while read db; do ./beeline.sh $opts -e "show tables from $db" | sed "s/^/$db./"; done
#
# row counts of all tables in all databases:
#
#   opts="--silent=true --outputformat=tsv2"; ./beeline.sh $opts -e 'show databases' | tail -n +2 | while read db; do ./beeline.sh $opts -e "show tables from $db" | sed "s/^/$db./"; done | tail -n +2 | while read table; do printf "%s\t" "$table"; ./beeline.sh $opts -e "select count(*) from $table" | tail -n +2; done | tee row_counts_hive.tsv

# see also: https://cwiki.apache.org/confluence/display/Hive/HiveServer2+Clients#HiveServer2Clients-Usinghive-site.xmltoautomaticallyconnecttoHiveServer2

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x

# not listed in hive-site.xml on edge nodes nor https://github.com/apache/hive/blob/master/data/conf/hive-site.xml
# must specify in your environment / .bashrc or similar
if [ -z "${HIVESERVER2_HOST:-}" ]; then
    echo "HIVESERVER2_HOST environment variable not set"
    exit 3
fi

opts=""
if [ -n "${BEELINE_OPTS:-}" ]; then
    opts="$opts;$BEELINE_OPTS"
fi

# xq -r < hive-site.xml '.configuration.property[] | select(.name == "hive.server2.use.SSL") | .value'
if [ -n "${HIVESERVER2_SSL:-}" ] ||
   grep -A1 'hive.server2.use.SSL' /etc/hive/conf/hive-site.xml 2>/dev/null |
   grep -q true; then
    opts="$opts;ssl=true"
    # works without this but enable if you need
    #set +o pipefail
    #trust_file="$(find /opt/cloudera/security/jks -maxdepth 1 -name '*-trust.jks' 2>/dev/null | head -n1)"
    #set -o pipefail
    #if [ -f "$trust_file" ]; then
    #    opts="$opts;sslTrustStore=$trust_file"
    #fi
fi

realm="${HIVESERVER2_HOST#*.}"

beeline -u "jdbc:hive2://$HIVESERVER2_HOST:10000/default;principal=hive/_HOST@${realm}${opts}" "$@"
