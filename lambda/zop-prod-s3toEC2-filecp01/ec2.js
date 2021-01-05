const AWS = require('aws-sdk');
const SSM = new AWS.SSM({apiVersion: '2020-08-04'});

// S3 → EC2
exports.download = async function(bucket, key) {
  // ファイル送信先である EC2 のディレクトリ
  var dir = '/tmp/jmc/s3_download/';
  // エラーログファイル
  var errorlog = '/var/log/zenikyo/error.log';
  
  // 実行するコマンド
  var commands = [
`\
if [ ! -e ${dir} ]; then \
sudo -u tomcat mkdir -p ${dir}; \
fi \
`,

`error=\`sudo -u tomcat aws s3 cp s3://${bucket}/${key} ${dir} 2>&1 >/dev/null\``,

`\
if [ -n "\${error}" ]; then \
echo "[\`date '+%Y/%m/%d %H:%M:%S'\`] Faild to download ${key} from S3." >> ${errorlog}; \
echo "[\`date '+%Y/%m/%d %H:%M:%S'\`] \${error}" >> ${errorlog}; \
else \
md5cs=\`openssl md5 -binary ${dir}${key} | base64\`; \
aws_md5cs=\`aws s3api head-object --bucket ${bucket} --key ${key} --query 'Metadata' | jq -r '.md5checksum'\`; \
if [ "\${md5cs}" = "\${aws_md5cs}" ]; then \
sudo -u tomcat unzip -o -P 3z061119 ${dir}${key} -d /; \
aws s3 rm s3://${bucket}/${key}; \
else \
echo "[\`date '+%Y/%m/%d %H:%M:%S'\`] Faild to download ${key} from S3." >> ${errorlog}; \
echo "[\`date '+%Y/%m/%d %H:%M:%S'\`] MD5 checksum integrity error." >> ${errorlog}; \
echo "[\`date '+%Y/%m/%d %H:%M:%S'\`] local file MD5 = \${md5cs}" >> ${errorlog}; \
echo "[\`date '+%Y/%m/%d %H:%M:%S'\`] S3 file MD5 = \${aws_md5cs}" >> ${errorlog}; \
fi; \
rm -f ${dir}${key}; \
fi \
`,
  ];
  
  // コマンド実行時のパラメータ
  var params = {
    DocumentName: 'AWS-RunShellScript',   // 必須らしい
    InstanceIds: ['i-0a2e31826d1b896cd'], // EC2 のインスタンスIDを指定
    Parameters: {
      commands: commands,
      executionTimeout: ['300']
    },
    TimeoutSeconds: 600 // コマンド実行のタイムアウト
  };
  
  // コマンド実行＆結果を返す
  return await SSM.sendCommand(params).promise().catch(e => console.error(e));
}
