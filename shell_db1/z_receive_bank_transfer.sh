#!/bin/bash

#
# 銀行振替結果取込バッチ用のシェルスクリプト
#

# SQSキューのURL
SQS_QUEUE=https://sqs.ap-northeast-1.amazonaws.com/889520124611/zop-prod-sqs01

# S3バケット名（ダウンロード先）
BUCKET_NAME_D="zop-prod-from-ec2"

# S3バケット名（アップロード先）
BUCKET_NAME_U="zop-prod-to-ec2"

# AWS CLIユーザー
AWSCLI_USER="data-linkage"

# ZIP化したファイルの一時配置場所（ダウンロード時）
ZIP_DIR_D=/home/jw/jmc_download/tmp/

# ZIP化したファイルの一時配置場所（アップロード時）
ZIP_DIR_U=/home/jw/jmc_upload/tmp/

# ZIP拡張子
EXT_ZIP=".zip"

# エラー出力先ファイル
ERROR_LOG_FILE=/var/log/zenikyo/error.log

# EC2へ処理結果を返すためのファイル名
RESULT_FILE_NAME="receive_result.txt"

# SQS用のディレクトリ
SQS_DIR=/home/jw/jmc_sqs/tmp/

# SQS検出済みメッセージIDリストのファイル
SQS_DUPLICATE_ID_LIST=${SQS_DIR}bank_result_id_list.txt

#####################################################################################################

# zipファイルの一時格納先ディレクトリが無かったら作成
if [ ! -e ${ZIP_DIR_D} ]
then
        mkdir -p ${ZIP_DIR_D}
fi
if [ ! -e ${ZIP_DIR_U} ]
then
        mkdir -p ${ZIP_DIR_U}
        touch ${SQS_DUPLICATE_ID_LIST}
fi

# SQS用のディレクトリが無かったら作成
if [ ! -e ${SQS_DIR} ]
then
        mkdir -p ${SQS_DIR}
fi

attributes=`aws sqs get-queue-attributes --queue-url ${SQS_QUEUE} --attribute-names ApproximateNumberOfMessages --profile ${AWSCLI_USER}`

# タブ文字で区切り、一番最後にある要素を取得（キューに存在するメッセージの個数）
msg_count=${attributes##*       }

for ((i=0; i<${msg_count}; i++))
do
        # ID重複フラグ
        is_duplicate=0

        # 戻り値
        # 1: "MESSAGE" 文字列
        # 2: Body
        # 3: MD5
        # 4: ID
        # 5: ReceiptHandle
        message=`aws sqs receive-message --queue-url ${SQS_QUEUE} --attribute-names ApproximateNumberOfMessages --profile ${AWSCLI_USER}`
        msgAttr=(${message//    / })

        header=${msgAttr[0]}
        body=${msgAttr[1]}
        md5=${msgAttr[2]}
        id=${msgAttr[3]}
        receiptHandle=${msgAttr[4]}

        # 重複したIDかどうかチェック
        cat ${SQS_DUPLICATE_ID_LIST} | while read received_id
        do
                if [ ${id} = ${received_id} ]
                then
                        is_duplicate=1
                        break
                fi
        done

        # IDが重複していた場合は処理をしない
        if [ ${is_duplicate} = 1 ]
        then
                continue
        fi

        # 銀行振替データ送信のファイルでなければスルー
        if [ ! `echo $body | grep 'bank_result'` ]
        then
                continue
        fi

        # ダウンロード対象のファイル名
        key=${body}

        # .zip拡張子を取り除いたファイル名（スラッシュがハイフンになっている状態）
        delextension=${key/${EXT_ZIP}/}

        # ディレクトリのパス
        dir_path=${delextension//-/\/}

        # S3よりファイルのダウンロード
        error=`aws s3 cp s3://${BUCKET_NAME_D}/${key} ${ZIP_DIR_D} --profile ${AWSCLI_USER} 2>&1 >/dev/null`

        # ファイルのダウンロードがエラーになった場合
        if [ -n "${error}" ]
        then
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」Could not download ${key} from S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」${error}" >> ${ERROR_LOG_FILE}

                continue
        fi

        # ダウンロードに成功した場合は、一度検出したメッセージIDを残しておく（重複検出用）
        echo ${id} >> ${SQS_DUPLICATE_ID_LIST}

        md5cs=`openssl md5 -binary ${ZIP_DIR_D}${key} | base64`
        aws_md5cs=`aws s3api head-object --bucket ${BUCKET_NAME_D} --key ${key} --query 'Metadata' --profile ${AWSCLI_USER} | jq -r '.md5checksum'`

        # MD5チェックサム値比較で整合性エラーになった場合
        if [ ${md5cs} != ${aws_md5cs} ]
        then
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」Could not download ${key} from S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」MD5 checksum integrity error." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」local file MD5 = ${md5cs}" >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」S3 file MD5 = ${aws_md5cs}" >> ${ERROR_LOG_FILE}

		rm ${ZIP_DIR_D}${key}

		exit 0
       fi

        # 解凍＆配置
        unzip -o -P 3z061119 ${ZIP_DIR_D}${key} -d /

        # S3のファイル削除
        error=`aws s3 rm s3://${BUCKET_NAME_D}/${key} --profile ${AWSCLI_USER} 2>&1 >/dev/null`

        # S3のファイル削除でエラーになった場合
        if [ -n "${error}" ]
        then
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」Could not remove ${key} on S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」${error}" >> ${ERROR_LOG_FILE}
        fi

        # ネットワーク種別をzipファイル名から判別
        n=${key%-*}
        network_type=${n##*-}

        # ISDN接続
        start_exit_code=`bankconnect.sh ${network_type} start`

        # ISDN接続に成功したか
        if [ ${start_exit_code} = 0 ]
        then
                # 解凍したディレクトリ下の要素ファイル名を取得
                transfer_setting_file_name=`ls ${dir_path} | grep .ini`

                # 全銀ミドル実行
                z_result=`/usr/local/zhostd/zclient ${dir_path}${transfer_setting_file_name}`
                z_result_code=$?

                # zclient標準出力と終了コードを結果ファイルに書込み
		echo 0 >> ${dir_path}${RESULT_FILE_NAME}
                echo z_result_code >> ${dir_path}${RESULT_FILE_NAME}
                echo z_result >> ${dir_path}${RESULT_FILE_NAME}

        else
                # ISDN接続に失敗した場合
                echo 1 >> ${dir_path}${result_file_name}
                echo ${start_exit_code} >> ${dir_path}${result_file_name}

                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」ISDN connection failed." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」ISDN connect result code : ${start_exit_code}" >> ${ERROR_LOG_FILE}
        fi

        # /data/jmc/jmc_w_bank/bank_result/[ネットワーク種別] 以下をZIP化
        zippath="${ZIP_DIR_U}${dir_path//\//-}${EXT_ZIP}"
        zip -er --password=3z061119 ${zippath} ${dir_path}

	# アプリへの結果返却用ファイルは削除
	rm ${dir_path}${RESULT_FILE_NAME}

	if [ ${start_exit_code} = 0 ]
	then
		# 送信済み用のディレクトリ（無ければ作成）
		ok_dir_path=${dir_path/bank_result/bank_result_ok}
		if [ ! -e ${ok_dir_path} ]
		then
			mkdir -p ${ok_dir_path}
		fi

		# 送信済み用のディレクトリへファイル移動
		mv ${dir_path}* ${ok_dir_path}
	fi

	# ISDN切断
        stop_exit_code=`bankconnect.sh ${network_type} stop`

	if [ ${stop_exit_code} = 0 ]
	then
                # ISDN切断に失敗した場合
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」ISDN disconnection failed." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」ISDN disconnect result code : ${stop_exit_code}" >> ${ERROR_LOG_FILE}
	fi
done

# S3へのファイルアップロード
upload_files=`find ${ZIP_DIR_U} -type f`
for upload_file in ${upload_files}
do
	key=${upload_file##*/}
        md5cs=`openssl md5 -binary ${zippath} | base64`
        error=`aws s3api put-object --bucket ${BUCKET_NAME_U} --key .${key} --body ${zippath} --content-md5 ${md5cs} --metadata md5checksum=${ms5cs} 2>&1 >/dev/null`

        if [ -n "${error}" ]
        then
		delextension=${key/${EXT_ZIP}/}
                originalpath=${delextension//-/\/}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」Could not upload ${originalpath} to S3." >> ${ERROR_LOG_FILE}
                echo "[`date '+%Y/%m/%d %H:%M:%S'`] 「Receive bank transfer data」${error}" >> ${ERROR_LOG_FILE}
	else
		# 送信済みZIPファイルの削除
		rm ${uplaod_file}
        fi
done
