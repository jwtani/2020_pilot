#!/bin/bash
set -u
umask 007

# 保険会社コード
ins_code=$1
# "ebcdic" | "ebcdic_old" | その他
char_code=$2

ym=`date +%Y%m`
infile=/data/jmc/${ins_code}.txt
outdir=/data/jmc/jmc_w_ins_trans/${ym}/${ins_code}
tmpfile=${outdir}/${ins_code}
outfile=${tmpfile}.txt

case "${char_code}" in
    ebcdic)
        iconv -f IBM930 -t UTF-8 ${infile} | nkf -x --windows > ${tmpfile}
        ;;
    ebcdic_old)       
        iconv -f EBCDIC-JP-KANA -t UTF-8 ${infile} | nkf -s > ${tmpfile}
        ;;
    *)
        cp /data/jmc/$1.txt $FILE.txt
        ;;
esac

