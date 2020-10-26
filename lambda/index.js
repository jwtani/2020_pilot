//イベントハンドラ（メイン）
exports.handler = async (event, context) => {
  // S3 のインスタンス名
  var bucket = event.Records[0].s3.bucket.name;
  // key（PUTのイベントがあったファイル名）
  var key = event.Records[0].s3.object.key;
  
  var sqs = require('./sqs.js');
  var ec2 = require('./ec2.js');
  
  // SQSメッセージ送信
  sqs.queueing(key);
  
  // EC2へZIPファイル送信＆解凍
  return ec2.download(bucket, key);
};
