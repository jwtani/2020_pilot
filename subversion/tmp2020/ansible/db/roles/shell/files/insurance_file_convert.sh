#!/bin/bash

BASE_DIR=/data/jmc
TRANS_DIR=${BASE_DIR}/jmc_w_ins_trans

DAIDO=00001

for FILE in `find $TRANS_DIR -regextype posix-basic -regex '^'${TRANS_DIR}'/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{5\}_[0-9]\{4\}\.txt$'`; do

  MONTH=`echo $FILE | cut -d"/" -f5`
  INSNO=`echo $FILE | cut -d"/" -f6`

  WORK_DIR=${TRANS_DIR}/${MONTH}/${INSNO}
  CMT_DIR=${BASE_DIR}/jmc_w_ins_cmt/${MONTH}/${INSNO}

  FILE_NAME=`echo $FILE | cut -d"/" -f7`

  FILE_SJIS=${WORK_DIR}/sjis.txt
  FILE_FIN=`echo $FILE_NAME | cut -d"_" -f2`
  FILE_LF=${WORK_DIR}/${FILE_FIN}

  iconv -f 'IBM930' -t 'IBM-943' $FILE -o $FILE_SJIS

  if [ $INSNO = $DAIDO ]; then
    fold -bw 600 $FILE_SJIS > $FILE_LF
  else
    fold -bw 300 $FILE_SJIS > $FILE_LF
  fi

  echo "" >> $FILE_LF
  unix2dos $FILE_LF
  cp $FILE_LF ${CMT_DIR}/${FILE_FIN}
  rm $FILE $FILE_SJIS $FILE_LF 
done
exit 0
