#!/bin/bash
set -u

DAIDO_CODE="00001"

BASE_DIR=/data/jmc
TRANS_DIR=${BASE_DIR}/jmc_w_ins_trans

for inputfile in `find ${TRANS_DIR} -regextype posix-basic -regex '^'${TRANS_DIR}'/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{5\}_[0-9]\{4\}\.txt$'`; do

  ym=`echo ${inputfile} | cut -d"/" -f5`
  ins=`echo ${inputfile} | cut -d"/" -f6`

  file_name=$(basename ${inputfile})

  # 例：00001_0001.txt → 0001.txt
  outputfile_name=`echo ${file_name} | cut -d"_" -f2`
  tempfile=${TRANS_DIR}/${ym}/${ins}/${outputfile_name}

  # 横幅を変更
  bw=300
  if [ ${ins} = ${DAIDO_CODE} ]; then
    bw=600
  fi

  # 文字コード変換
  iconv -f 'IBM930' -t 'IBM-943' ${inputfile} | fold -bw ${bw} > ${tempfile}
  echo "" >> ${tempfile}
  unix2dos ${tempfile}

  # ファイル移動
  outputfile=${BASE_DIR}/jmc_w_ins_cmt/${ym}/${ins}/${outputfile_name}
  mv ${tempfile} ${outputfile} && rm ${inputfile}
done

exit 0
