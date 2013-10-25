#!/bin/sh

### examples:
# adept.sh -1 svn /home/adept/svn/MyProject/trunk
# adept.sh -c /etc/adept.conf

configfile=/usr/local/etc/adept.conf

init_vars(){
	projecttype=$1
	projectdir=$2
	logfile=`mktemp -q /tmp/adept_log.XXXXXX` || exit 1
}

failed(){
	logger ADEPT deployment of $projectdir failed. Logged to $logfile
}

run_stage(){
	for x in $@; do
		if [ -x ./$x ] ; then
			echo "$x:" >>$logfile
			./$x  >>$logfile 2>&1 || return 1
		fi
	done

	rm $logfile

	return 0
}

deploy(){
	logger ADEPT deploying $projectdir
	cd $projectdir/adept

	run_stage predeploy deploy postdeploy || failed
}

run_single(){
	init_vars $@

	cd $projectdir

	if [ $projecttype = "svn" ] ; then
		if [ "`svn info -r HEAD | grep 'Last Changed Rev'`" != "`svn info | grep 'Last Changed Rev'`" ] ; then
			svn update --non-interactive >/dev/null 2>&1
			deploy
		fi
	elif [ $projecttype = "git" ] ; then
		git pull | grep 'Already up-to-date.' >/dev/null 2>&1 || deploy
	fi
}

batch_run(){
	. $configfile

	IFS=":"

	for x in $svn_deployments; do
		run_single svn $x
	done

	for x in $git_deployments; do
		run_single git $x
	done
}

while getopts ":1c" opt; do
	case $opt in
		1)
			shift $(($OPTIND-1))
			run_single $@
			exit 0
			;;
		c)
			shift $(($OPTIND-1))
			configfile=$1
			batch_run
			exit 0
			;;
		?)
			echo Invalid option
			;;
	esac
done

batch_run

exit 0
