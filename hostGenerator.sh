file="/kube-openmpi/generated/hostfile"
while :
do
    while IFS= read line
    do
        getent hosts $line | awk '{ print $1 }'
    done < "$file" > /kube-openmpi/generated/host
    sleep 5
done