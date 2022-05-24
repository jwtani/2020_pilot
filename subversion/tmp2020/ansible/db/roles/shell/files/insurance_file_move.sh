#!/bin/bash
set -u

# 保険会社コード
INS_CODE=$1

# "ebcdic" | "ebcdic_old" | その他
CHAR_CODE=${2-}

# メール送信先アドレス
TO_ADDR=hoken@zen-ikyo.or.jp

# 全銀ミドル出力ファイルを変換し移動
file_trans_cp932() {
    local inscode=$1
    local charcode=${2-}
    local ym=`date +%Y%m`
    local infile=/data/jmc/${inscode}.txt
    local outdir=/data/jmc/jmc_w_ins_trans/${ym}/${inscode}
    local tmpfile=${outdir}/${inscode}
    local outfile=${tmpfile}.txt
    local return_code=0

    case "${charcode}" in
        ebcdic)
            iconv -f IBM930 -t UTF-8 ${infile} | nkf -x --windows > ${tmpfile}
            return_code=$?
            ;;
        ebcdic_old)
            iconv -f EBCDIC-JP-KANA -t UTF-8 ${infile} | nkf -s > ${tmpfile}
            return_code=$?
            ;;
        *)
            cp ${infile} ${tmpfile}
            return_code=$?
            ;;
    esac

    if [ ${return_code} -ne 0 ]; then
        return ${return_code}
    fi

    mv ${tmpfile} ${outfile}
    return_code=$?

    if [ ${return_code} -ne 0 ]; then
        return ${return_code}
    fi

    chmod 0770 ${outfile}
    return_code=$?

    return ${return_code}
}

# メール送信
send_mail_insurance() {
    local toaddr=$1
    local inscode=$2
    local subject
    local ym ymstr

    # 処理年月取得 eg. 2022年2月
    ym=`date +%Y年%m月`
    ymstr=${ym/年0/年}
    subject="${ymstr}分保険会社[${inscode}]請求ファイル受信"
    body="保険会社[${inscode}]から${ymstr}分の保険請求ファイルを受信しました。"

    echo "${body}" | mutt -s "${subject}" ${toaddr}
    return $?
}

file_trans_cp932 ${INS_CODE} ${CHAR_CODE}
return_code=$?

if [ ${return_code} -ne 0 ]; then
    exit ${return_code}
fi

send_mail_insurance ${TO_ADDR} ${INS_CODE}
return_code=$?

if [ ${return_code} -ne 0 ]; then
    exit ${return_code}
fi

exit 0
