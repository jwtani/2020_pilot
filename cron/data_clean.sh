#!/bin/bash

#
# データクリーンバッチ
#

JMC_DIR=/data/jmc
ERRLOG_DIR=/var/log/zenikyo

# 直近何日分のファイルを保持するか
JMC_SAVE_DAYS=60
LOG_SAVE_DAYS=180

find ${JMC_DIR} -type f -mtime +${JMC_SAVE_DAYS} -delete
find ${JMC_DIR} -type d -empty -mtime +${JMC_SAVE_DAYS} -delete
find ${ERRLOG_DIR} -type f -mtime +${LOG_SAVE_DAYS} -delete
