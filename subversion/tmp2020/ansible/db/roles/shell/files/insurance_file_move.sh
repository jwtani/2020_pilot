#!/bin/bash
umask 003
#YM=`ls -D /data/jmc/jmc_w_ins_trans/  | tr -d /`
YM=`date +%Y%m`
FILE=/data/jmc/jmc_w_ins_trans/$YM/$1/$1

case "$2" in
    ebcdic)
        #mv /data/jmc/$1.txt $FILE.ebcdic
        cp /data/jmc/$1.txt $FILE.ebcdic
        iconv -f IBM930 -t UTF-8 $FILE.ebcdic > $FILE.utf
        nkf -x --windows $FILE.utf > $FILE.txt
        rm $FILE.ebcdic
        rm $FILE.utf
        ;;
    ebcdic_old)       
        #mv /data/jmc/$1.txt $FILE.ebcdic
        cp /data/jmc/$1.txt $FILE.ebcdic
        iconv -f EBCDIC-JP-KANA -t UTF-8 $FILE.ebcdic > $FILE.utf
        nkf -s $FILE.utf > $FILE.txt
        rm $FILE.ebcdic
        rm $FILE.utf
        ;;
    *)
        #mv /data/jmc/$1.txt $FILE.txt
        cp /data/jmc/$1.txt $FILE.txt
        ;;
esac

chmod 770 /data/jmc/jmc_w_ins_trans/$YM/$1/$1.txt
