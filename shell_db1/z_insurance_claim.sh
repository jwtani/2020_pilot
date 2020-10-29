#!/bin/bash

#
# 保険請求データ取込バッチ用のシェルスクリプト
#

# 何分前に更新されたファイルをアップロード対象とするか(3を設定すれば3分前から現在までに更新されたファイルを対象とする）
SEARCH_MIN=1

# ZIP化したファイルの一時配置場所
ZIP_DIR=/home/jw/jmc_upload/tmp/

# ZIP拡張子
EXT_ZIP=".zip"

# 送信先S3バケット名
BUCKET_NAME="zop-prod-to-ec2"

# AWS CLIユーザー
AWSCLI_USER="data-linkage"

# エラーログファイル格納ディレクトリ
ERROR_LOG_DIR=/var/log/zenikyo/

# エラー出力先ファイル
ERROR_LOG_FILE=${ERROR_LOG_DIR}error.log

#####################################################################################################

# エラーログ出力先が無ければ作成
if [ ! -e ${ERROR_LOG_DIR} ]
then
        mkdir ${ERROR_LOG_DIR}
fi

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR} ]
then
        mkdir -p ${ZIP_DIR}
fi

targets=`find /data/jmc/jmc_w_ins_cmt/ -type f -mmin -${SEARCH_MIN}`
for target in $targets
do
        # ファイルのZIP化
        zippath="${ZIP_DIR}${target//\//-}${EXT_ZIP}"
        zip -er --password=3z061119 ${zippath} ${target}
done

# S3へのファイルアップロード
uploadfiles=`find ${ZIP_DIR} -type f`
for uploadfile in $uploadfiles
do
        key=${uploadfile##*/}
        md5cs=`openssl md5 -binary ${uploadfile} | base64`
        error=`aws s3api put-object --bucket ${BUCKET_NAME} --key .${key} --body ${uploadfile} --content-md5 ${md5cs} --metadata md5checksum=${md5cs} --profile ${AWSCLI_USER} 2>&1 >/dev/null`

        # 送信エラーになった場合
        if [ -n "${error}" ]
        then
                delextension=${key/${EXT_ZIP}/}
                originalpath=${delextension//-/\/}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」Could not upload ${originalpath} to S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Insurance claim data」${error}" >> ${ERROR_LOG_FILE}
	else
		# 送信済みZIPファイルの削除
		rm ${uploadfile}
        fi
done
