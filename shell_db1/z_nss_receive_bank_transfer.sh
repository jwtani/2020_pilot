#!/bin/bash

#
# 銀行振替結果取込（NSS）用のシェルスクリプト
#

# S3バケット名
BUCKET_NAME="zop-prod-to-ec2"

# AWS CLIユーザー
AWSCLI_USER="data-linkage"

# ZIP化したファイルの一時配置場所
ZIP_DIR=/home/jw/jmc_upload/nss/

# ZIP拡張子
EXT_ZIP=".zip"

# エラー出力先ファイル
ERROR_LOG_FILE=/var/log/zenikyo/error.log

#####################################################################################################

# 前月の値取得
ym=`date +%Y%m --date '1 month ago'`

# 現在日付が 20以上 であれば前月ではなく当月のディレクトリを検索する
now_d=`date +%d`
if [ ${now_d} -ge 20 ]
then
	ym=`date +%Y%m`
fi

# 送信対象のNSS伝送ファイルの検索
result=`find /data/jmc/jmc_w_bank/${ym}/bank_result/NSS -type f -name NSS_RECEIVE_DEC.txt`
if [ "${result}" = "" ]
then
	# 対象ファイル無し
	exit 0
fi

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]
then
        mkdir -p ${ZIP_DIR}
fi

target_file=${result/NSS_RECEIVE_DEC.txt/NSS_RECEIVE.txt}
mv ${result} ${target_file}

# S3へ送信するZIPファイルのパス
zip_path="${ZIP_DIR}${target_file//\//-}${EXT_ZIP}"

# ディレクトリのZIP化
zip -er --password=3z061119 ${zip_path} ${target_file}

# S3へのファイルアップロード
key=${zip_path##*/}
md5cs=`openssl md5 -binary ${zip_path} | base64`
error=`/usr/local/bin/aws s3api put-object --bucket ${BUCKET_NAME} --key .${key} --body ${zip_path} --content-md5 ${md5cs} --metadata md5checksum=${md5cs} --profile ${AWSCLI_USER} 2>&1 >/dev/null`

if [ -n "${error}" ]
then
	# 送信エラーになった場合
	echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data NSS」Could not upload ${target_file} to S3." >> ${ERROR_LOG_FILE}
	echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data NSS」${error}" >> ${ERROR_LOG_FILE}
	exit 0
fi

# 送信済み用のディレクトリ作成
ok_dir_path=${target_file/jmc_w_bank/jmc_w_history}
ok_dir_path=${ok_dir_path/bank_result/bank_result_ok}
ok_dir_path=${ok_dir_path%/*}
dir_timestamp=`date +%Y%m%d_%H%M%S%3N`
ok_dir_path=${ok_dir_path}/${dir_timestamp}
mkdir -p ${ok_dir_path}

# 送信済み用のディレクトリへファイル移動
mv ${target_file} ${ok_dir_path}

# 送信済みZIPファイルの削除
rm ${zip_path}
