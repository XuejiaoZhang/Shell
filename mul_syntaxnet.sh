#!/bin/bash
#########################
## 多进程实现解析汉语句子结构##
## 2016-12-20 
## Version 1.0 
#########################


srcFile='/export/ml/pinyin_test/mobile_pai_20160926_fulltext.txt'
#srcFile='hanzi.txt'
jiebaSplitFile='jieba.txt'
MODEL_DIRECTORY='/export/ml/Chinese'

#使用jieba分词
echo "开始分词",
date
python -m jieba $srcFile > $jiebaSplitFile
sed  -i 's/\///g' $jiebaSplitFile
date
echo "分词完成"

#使用syntaxNet自带分词
#syntaxNetSplitFile='output_token_hanzi.conll'
#cat $srcFile | syntaxnet/models/parsey_universal/tokenize_zh.sh $MODEL_DIRECTORY > $syntaxNetSplitFile

#使用syntaxNet解析句子结构
echo "开始解析",
date
syntaxNetParseFile='fulltext_output_parse_hanzi.conll'
resultDir='parseResult'

if [ -e $syntaxNetParseFile ];
then
    rm -f $syntaxNetParseFile
fi
if [ -e $resultDir ];
then
    rm -rf $resultDir
fi
mkdir -p $resultDir

#将文件描述符1000与FIFO进行绑定
tempfifo=$$.fifo        # $$表示当前执行文件的PID
trap "exec 1000>&-;exec 1000<&-;exit 0" 2
mkfifo $tempfifo
exec 1000<>$tempfifo
rm -rf $tempfifo

#设置进程数目为8
for ((i=1; i<=8; i++))
do
    echo >&1000
done

#利用多进程执行,每个进程处理100000行
filename=$jiebaSplitFile
total=`cat $filename|wc -l`
m=1
incre=3
#incre=99999
filenum=1
while true
do
    if [ $[$m+$incre] -lt $total ];
    then
        n=$[$m+$incre]
        read -u1000
        {
	    sed -n "$m,$n p" $filename |syntaxnet/models/parsey_universal/parse.sh $MODEL_DIRECTORY >> $resultDir/$syntaxNetParseFile$filenum 
            echo >&1000
        } &
        m=$[$n+1]
    else
        read -u1000
        {
	    sed -n "$m,$ p" $filename |syntaxnet/models/parsey_universal/parse.sh $MODEL_DIRECTORY >> $resultDir/$syntaxNetParseFile$filenum 
            echo >&1000
        } &
	break
    fi
    filenum=$[$filenum+1]
done
wait

echo "开始合并解析结果",
date
for file in $(ls $resultDir)
do
    cat $resultDir/$file >> $resultDir/$syntaxNetParseFile
done

echo "完成", $syntaxNetParseFile,
date
