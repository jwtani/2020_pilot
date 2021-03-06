//イベントハンドラ（メイン）
exports.handler = async (event, context, callback) => {
  // key（アップロードのイベントがあったファイル名）
  var key = event.Records[0].s3.object.key;
  
  var sqs = require('./sqs.js');
  
  // SQSメッセージのキューイング
  sqs.queueing(key);
  
  callback(null, 'Message queueing process end.');
};
