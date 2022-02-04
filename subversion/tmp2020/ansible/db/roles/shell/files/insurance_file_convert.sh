#!/bin/bash
set -u

DAIDO_CODE="00001"

BASE_DIR=/data/jmc
TRANS_DIR=${BASE_DIR}/jmc_w_ins_trans

infiles=`find ${TRANS_DIR} -regextype posix-basic \
    -regex '^'${TRANS_DIR}'/[0-9]\{6\}/[0-9]\{5\}/[0-9]\{5\}_[0-9]\{4\}\.txt$'`
for infile in ${infiles}; do
    ym=`echo ${infile} | cut -d"/" -f5`
    ins=`echo ${infile} | cut -d"/" -f6`

    file_name=$(basename ${infile})

    # 例：00001_0001.txt → 0001.txt
    outfile_name=`echo ${file_name} | cut -d"_" -f2`
    tmpfile=${TRANS_DIR}/${ym}/${ins}/${outfile_name}

    # 横幅を変更
    bw=300
    if [ ${ins} = ${DAIDO_CODE} ]; then
        bw=600
    fi

    # 文字コード変換
    iconv -f 'IBM930' -t 'IBM-943' ${infile} | fold -bw ${bw} > ${tmpfile}
    echo "" >> ${tmpfile}
    unix2dos ${tmpfile}

    # ファイル移動
    outfile=${BASE_DIR}/jmc_w_ins_cmt/${ym}/${ins}/${outfile_name}
    mv ${tmpfile} ${outfile} && rm ${infile}
done

exit 0
