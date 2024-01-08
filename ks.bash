#!/bin/bash

SUH="user@hostname.tld"
SFN="/home/user/somedir"

SF=()
SF+=("kanji_data")
SF+=("user_data")

RFL=()
LFL=()

function a_appinstalled()
{
    res=$( su -c 'if [ -d /data/data/ua.syt0r.kanji.fdroid ]; then echo "1"; else echo "0"; fi' )
    echo "$res"
}

function a_appstopped()
{
    res="$(su -c 'ps -ef' | sed -ne '/ua.syt0r.kanji.fdroid$/{/^u0_/{/grep/{d};s/[^\t ]*[\t ]\+//;s/[\t ]\+.*//;p}}' )"

    if [ "$res" != "" ]
    then
	su -c "kill $res"
	echo "killed $res"
    fi
}

function getusername()
{
    res=$( su -c "stat -c '%U' /data/data/ua.syt0r.kanji.fdroid/databases" )
    echo "$res" >&2
    echo "$res"
}

function printlist()
{
    local -n list=$1
    local len=${#list[@]}

    echo "len: $len"

    for((i=0;i<$len;i++))
    do
	echo "${list[$i]}"
    done
}

function getremotefilelist()
{
    RFL=()

    while IFS= read -r line
    do
	RFL+=("$line")
    done <<< $(ssh $SUH 'cd '$SFN' ; stat -c "%Y %n %s" *__[0-9a-f]*__.[if]b 2>/dev/null | sort -gr' )
}

function getlocalfilelist()
{
    LFL=()

    while IFS= read -r line
    do
	LFL+=("$line")
    done <<< $(su -c 'cd /data/data/ua.syt0r.kanji.fdroid/databases/ ; stat -c "%Y %n %s" *__[0-9a-f]*__.[if]b 2>/dev/null | sort -gr' )
}

function findnewestbackup()
{
    local -n list=$1
    local filename=$2
    local btype=$3

    printlist $1 | sed -ne "/ ${filename}__[0-9a-f]*__\.${btype}/{s/[^ ]* //;s/ .*$//;p;q};/${filename}__[0-9a-f]*__\.fb/q"

}

function makefullbackup()
{
    su -c "rm -f /data/data/ua.syt0r.kanji.fdroid/databases/*.fb"

    for i in ${SF[@]}
    do
	cs=$(su -c "md5sum < /data/data/ua.syt0r.kanji.fdroid/databases/$i" | sed -e "s/ .*//")
	echo "$cs" >&2

	su -c "cp /data/data/ua.syt0r.kanji.fdroid/databases/$i /data/data/ua.syt0r.kanji.fdroid/databases/${i}__${cs}__.fb"
	echo "${i}__${cs}__.fb"
    done

    su -c "rm -f /data/data/ua.syt0r.kanji.fdroid/databases/*.ib"
}

function transferfiles()
{
    for i in $1
    do
	su -c "/data/data/com.termux/files/usr/bin/scp /data/data/ua.syt0r.kanji.fdroid/databases/$i $SUH:$SFN"
    done

    #su -c "/data/data/com.termux/files/usr/bin/scp $ffn $SUH:$SFN"
}

function makeincrementalbackup()
{
    for((i=0;i<${#SF[@]};i++))
    do
	localfullbackup=$(findnewestbackup LFL "${SF[$i]}" "fb")
	localincrbackup=$(findnewestbackup LFL "${SF[$i]}" "ib")
	remotefullbackup=$(findnewestbackup RFL "${SF[$i]}" "fb")
	remoteincrbackup=$(findnewestbackup RFL "${SF[$i]}" "ib")

	su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; /data/data/com.termux/files/home/bin/sqldiff $localfullbackup ${SF[$i]} | grep -v 'android_metadata ' > diff.sql;"
	ibs=$( su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; stat -c '%s' diff.sql" )
	echo "S: $ibs"

	if [ "$ibs" -gt "0" ]
	then
	    if [ "$ibs" -gt "100000" ]
	    then
		su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm ${localfullbackup}"
		su -c "rm -f /data/data/ua.syt0r.kanji.fdroid/databases/${SF[$i]}__*.ib"

		cs=$(su -c "md5sum < /data/data/ua.syt0r.kanji.fdroid/databases/${SF[$i]}" | sed -e "s/ .*//")
		echo "$cs" >&2

		su -c "cp /data/data/ua.syt0r.kanji.fdroid/databases/${SF[$i]} /data/data/ua.syt0r.kanji.fdroid/databases/${SF[$i]}__${cs}__.fb"

		ssh ${SUH} "cd ${SFN}; rm -f ${SF[$i]}__*.fb; rm -f ${SF[$i]}__*.ib"

		su -c "/data/data/com.termux/files/usr/bin/scp /data/data/ua.syt0r.kanji.fdroid/databases/${SF[$i]}__*.fb $SUH:$SFN"
		su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm diff.sql"
	    else
		su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; gzip diff.sql"
		md5=$( su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; md5sum < diff.sql.gz" | sed -e "s/ .*//" )

		echo "li: $localincrbackup"
		echo "ri: $remoteincrbackup"

		if [ "$remoteincrbackup" != "${SF[$i]}__${md5}__.ib" ]
		then
		    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; mv diff.sql.gz ${SF[$i]}__${md5}__.ib ; /data/data/com.termux/files/usr/bin/scp ${SF[$i]}__${md5}__.ib ${SUH}:${SFN}/${SF[$i]}__${md5}__.ib"
		else
		    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm diff.sql.gz"
		fi

		if [ "$localincrbackup" != "" -a "$localincrbackup" != "${SF[$i]}__${md5}__.ib" ]
		then
		    echo "del local $localincrbackup"
		    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm ${remoteincrbackup}"
		    echo "del remote $localincrbackup"
		    ssh ${SUH} "cd ${SFN}; rm -f ${localincrbackup}"
		fi

		if [ "$remoteincrbackup" != "" -a "$remoteincrbackup" != "${SF[$i]}__${md5}__.ib" ]
		then
		    echo "del remote $remoteincrbackup"
		    ssh ${SUH} "cd ${SFN}; rm -f ${remoteincrbackup}"
		fi
	    fi
	else
	    echo "no changes for ${SF[$i]}"
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm diff.sql"
	fi
    done
}

function applyupdates()
{
    for((i=0;i<${#SF[@]};i++))
    do
	localfullbackup=$(findnewestbackup LFL "${SF[$i]}" "fb")
	localincrbackup=$(findnewestbackup LFL "${SF[$i]}" "ib")
	remotefullbackup=$(findnewestbackup RFL "${SF[$i]}" "fb")
	remoteincrbackup=$(findnewestbackup RFL "${SF[$i]}" "ib")

	if [ "$localfullbackup" != "$remotefullbackup" ]
	then
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; /data/data/com.termux/files/usr/bin/scp ${SUH}:${SFN}/${remotefullbackup} ."
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm -f ${localfullbackup} ; cp ${remotefullbackup} ${SF[$i]}"
	else
	    echo "full backup of ${SF[$i]} is up to date."
	fi

	if [ "$remoteincrbackup" != "" -a "$localincrbackup" != "$remoteincrbackup" ]
	then
	    localfullbackup="$remotefullbackup"
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; /data/data/com.termux/files/usr/bin/scp ${SUH}:${SFN}/${remoteincrbackup} ."
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; rm -f ${localincrbackup}; mv ${remoteincrbackup} ${remoteincrbackup}.gz; gzip -d ${remoteincrbackup}.gz"
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; cp $localfullbackup ${SF[$i]} ; echo -e 'PRAGMA synchronous = 0;\nPRAGMA cache_size = 1000000;\nPRAGMA locking_mode = EXCLUSIVE;\nPRAGMA temp_store = MEMORY;' | cat - ${remoteincrbackup} | /data/data/com.termux/files/usr/bin/sqlite3 -batch ${SF[$i]}"
#	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; echo -e '\n' | cat - ${remoteincrbackup} | /data/data/com.termux/files/usr/bin/sqlite3 -batch ${SF[$i]}"
	    su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; gzip ${remoteincrbackup}; mv ${remoteincrbackup}.gz ${remoteincrbackup}"
	else
	    echo "incremental backup of ${SF[$i]} is up to date."
	fi
    done
}

if [ "`a_appinstalled`" == "0" ]
then
    echo "Kanji Dojo not installed!"
    exit
fi

a_appstopped

echo "TEST"

#DHOST="`getprop | sed -ne '/\[ro.product.model\]/{s/^[^:]*: //;s/\[//;s/\]//;p}'`"
KUSER="`getusername`"
KMD5=

#echo "$DHOST"
getremotefilelist
getlocalfilelist

#for((i=0;i<${#RFL[@]};i++))
#do
#    echo "${RFL[$i]}"
#done

printlist RFL
echo "-----"
printlist LFL
echo "-----"

localbackupfound=$(findnewestbackup LFL "${SF[0]}" "fb" | wc -l)
remotebackupfound=$(findnewestbackup RFL "${SF[0]}" "fb" | wc -l)

# all new! assume we have the most current version and replicate
if [ "$localbackupfound" == "0" -a "$remotebackupfound" == "0" ]
then
    echo "0 0"
    filenames="$(makefullbackup)"
    echo "$filenames"
    transferfiles "$filenames"
fi

# new client! remote repository contains backup. download
if [ "$localbackupfound" == "0" -a "$remotebackupfound" == "1" ]
then
    echo "0 1"

    applyupdates
fi

# odd! switched to new empty repository? replicate!
if [ "$localbackupfound" == "1" -a "$remotebackupfound" == "0" ]
then
    echo "1 0"

    filenames="$( for((i=0;i<${#LFL[@]};i++)); do echo \"${LFL[$i]}\"; done | sed -e 's/[^ ]* //;s/ .*//' )"

    echo "$filenames"

    transferfiles "$filenames"
fi

# normal! let's see ...
if [ "$localbackupfound" == "1" -a "$remotebackupfound" == "1" ]
then
    echo "1 1"

    applyupdates
fi

su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; chown ${KUSER}:${KUSER} *"

am start --user 0 -n ua.syt0r.kanji.fdroid/ua.syt0r.kanji.presentation.screen.main.FdroidMainActivity
res="$(su -c 'ps -ef' | sed -ne '/ua.syt0r.kanji.fdroid$/{/^u0_/{/grep/{d};s/[^\t ]*[\t ]\+//;s/[\t ]\+.*//;p}}' )"
tail --pid $res -f /dev/null

echo "finished"

#getlocalfilelist
#printlist LFL
#echo "-----"
makeincrementalbackup
su -c "cd /data/data/ua.syt0r.kanji.fdroid/databases ; chown ${KUSER}:${KUSER} *"

getremotefilelist
getlocalfilelist

printlist RFL
echo "-----"
printlist LFL
echo "-----"
