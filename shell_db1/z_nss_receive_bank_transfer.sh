#!/bin/bash

#
# 銀行振替結果取込（NSS）用のシェルスクリプト
#

# S3バケット名
BUCKET_NAME="zop-prod-to-ec2"

# AWS CLIユーザー
AWSCLI_USER="data-linkage"

# ZIP化したファイルの一時配置場所
ZIP_DIR=/home/jw/jmc_upload/tmp_nss/

# ZIP拡張子
EXT_ZIP=".zip"

# エラー出力先ファイル
ERROR_LOG_FILE=/var/log/zenikyo/error.log

# 引数で渡されたNSS振替結果ファイルパス
TARGET_FILE=$1

#####################################################################################################

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]
then
        mkdir -p ${ZIP_DIR}
fi

# S3へ送信するZIPファイルのパス
zip_path="${ZIP_DIR}${TARGET_FILE//\//-}${EXT_ZIP}"

# ディレクトリのZIP化
zip -er --password=3z061119 ${zip_path} ${TARGET_FILE}

# S3へのファイルアップロード
upload_files=`find ${ZIP_DIR} -type f`
for upload_file in ${upload_files}
do
	key=${zip_path##*/}
	md5cs=`openssl md5 -binary ${zip_path} | base64`
	error=`aws s3api put-object --bucket ${BUCKET_NAME} --key .${key} --body ${zip_path} --content-md5 ${md5cs} --metadata md5checksum=${md5cs} --profile ${AWSCLI_USER} 2>&1 >/dev/null`

	# 送信エラーになった場合
	if [ -n "${error}" ]
	then
		echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data NSS」Could not upload ${TARGET_FILE} to S3." >> ${ERROR_LOG_FILE}
		echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data NSS」${error}" >> ${ERROR_LOG_FILE}
	else
		# 送信済みZIPファイルの削除
		rm ${upload_file}
	fi
done
