#!/bin/bash
#磁盘io压测

#全局配置
configureParam() {
	maxStressPercent=75	#压测消耗磁盘空间比例%
	minThreads=128		#iozone压测的进程数,注意最大为256，因iozone最多支持256
	size=2			#iozone压测的每个文件大小,G为单位
	minsize=0.016		#iozone压测的写入文件size最小值16M
	dir=/export/iotest_dir 	#压测写入文件路径
	maxPercent=80 		#监控磁盘使用率%，达到上限终止压测
}

#检查参数是否合理
checkParam() {
	if [ $minThreads -gt 256 ];then
		minThreads=256
		echo "Warning:iozone支持最多256进程，所设置进程数超出上限，强制设置为256"
	fi
	if [ $maxStressPercent -gt 100 ];then
		maxStressPercent=75
		echo "Warning:压测消耗磁盘空间比例maxStressPercent，所设置值超出100，强制设置为75"
	fi
	if [ $maxPercent -gt 100 ];then
		maxPercent=80
		echo "Warning:监控磁盘使用率上限maxPercent，所设置值超出100，强制设置为80"
	fi
	if ! echo $dir |grep "^/export/";then
		dir=/export/iotest_dir 
		echo "Warning:压测写入文件目录需为/export下，强制设置为dir=/export/iotest_dir "
	fi

}

#保证压测工具存在可用
ifIozoneBinExist() {
	which iozone &>/dev/null
	if [ $? -ne 0 ];then
		echo "安装iozone中,请耐心等待"
		tar -xvf iozone3_429.tar &>/dev/null
		cd iozone3_429/src/current
		make &>/dev/null 
		make linux-ia64 &>/dev/null
		ln -s `pwd`/iozone /usr/bin/iozone
		which iozone &>/dev/null
		if [ $? -ne 0 ];then
			echo "安装iozone失败，退出"
			exit 1
        	else
		        echo "安装iozone成功"
		fi		
	else
		echo "iozone命令存在"
	fi
}

stressTest() {
	#计算/export可用空间
	diskAvai=$(df -h|grep "/export$"|awk -F" " '{print $4}')
	if echo $diskAvai|grep "T" &>/dev/null; then
		num=$(echo $diskAvai|awk -F"T" '{print $1}')
		diskAvaiSize=$(awk -v num=$num 'BEGIN{print num*1000 }')
	elif echo $diskAvai|grep "G" &>/dev/null ; then
		diskAvaiSize=$(echo $diskAvai|awk -F"G" '{print $1}')
	else
		echo "请确认/export可用空间大小,退出"
		exit 2
	fi
	echo "/export可用空间大小为 $diskAvaiSize G"

	#依据磁盘可用空间大小，计算出合理的压测值，线程数，文件大小
	while true 
	do
		threads=$(awk -v diskAvaiSize=$diskAvaiSize -v maxStressPercent=$maxStressPercent -v size=$size 'BEGIN{print diskAvaiSize*maxStressPercent/100/size }')
		if [ $(echo $threads|awk -F"." '{print $1}') -lt $minThreads ];then
			size=$(awk -v size=$size 'BEGIN{print size/2 }')
		else
			break
		fi 
		if [ $(awk -v size=$size -v minsize=$minsize 'BEGIN{if (size>minsize) { print "yes"} else { print "no" }}') -eq no ];then 
			echo "请确认磁盘空间，iozone设置文件size值 $size G过小，退出"
			exit 5
		fi
	done
	#echo  diskAvaiSize:$diskAvaiSize,threads:$threads,size:$size

	#压测
	if [ ! -d $dir ]; then
		mkdir -p $dir
	fi
	cd $dir
	if [ $? -eq 0 ];then 
		concurrency=$(awk -v threads=$threads -v minThreads=$minThreads 'BEGIN{print threads/minThreads }')
		count=0
		for i in $(seq 1 $concurrency)
		do
			nohup iozone -s $[size]G -i 0 -i 1 -i 2 -i 3 -i 4 -i 5 -i 8 -t $minThreads -G -o -B -Rb iozone.xls &>/dev/null &
			count=$[$count+1]
		done
		echo "并发 $count 执行命令：iozone -s $size G -i 0 -i 1 -i 2 -i 3 -i 4 -i 5 -i 8 -t $minThreads -G -o -B -Rb iozone.xls"
	else
		echo "创建压测目录失败，退出"
		exit 4
	fi 
}

#监控磁盘空间利用率，达到上限终止压测
diskMonitor() {
	echo
	echo "************************************************"
	echo "以磁盘空间80%为上限，压测中..."
	echo "终止压测，请按 【Ctrl+C】"
	echo "终止后请确认iozone进程已结束(ps aux|grep iozone)"
	echo "************************************************"
	while true
	do
		diskPercent=$(df -h|grep "/export$"|awk -F" " '{print $5}'|awk -F"%" '{print $1}')	
		if [ $diskPercent -gt $maxPercent ];then
			cleanUp
			echo "磁盘空间占用超过上限$maxPercent%，退出"
			exit 3
		fi
		sleep 5
	done
}


#清理压测进程及文件
cleanUp() {
	echo "清理压测进程及文件"
	for pid in $(ps aux|grep iozone|grep -v grep|awk -F" " '{print $2}'); do kill -9 $pid ; done
	\rm -f $dir/*
}

#主程序
main() {
	configureParam
	checkParam
	ifIozoneBinExist
	stressTest
	diskMonitor
}

main
