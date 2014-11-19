require 'cgi'
require 'net/http'
require 'rexml/document'
require 'json'
require 'twitter'
require 'tweetstream'

CLIENT_ID       = ENV["TRANS_CLIENT_ID"]
CLIENT_SECRET   = ENV["TRANS_CLIENT_SECRET"]
AUTHORIZE_URL   = 'https://datamarket.accesscontrol.windows.net/v2/OAuth2-13'
TRANSLATION_URL = 'http://api.microsofttranslator.com/V2/Http.svc/Translate'
SCOPE           = 'http://api.microsofttranslator.com'

BOT_CONSUMER_KEY = ENV["BOT_CONSUMER_KEY"]
BOT_CONSUMER_SECRET = ENV["BOT_CONSUMER_SECRET"]
BOT_ACCESS_TOKEN = ENV["BOT_ACCESS_TOKEN"]
BOT_ACCESS_TOKEN_SECRET = ENV["BOT_ACCESS_TOKEN_SECRET"]

cli = Twitter::REST::Client.new do |config|
  config.consumer_key       = BOT_CONSUMER_KEY
  config.consumer_secret    = BOT_CONSUMER_SECRET
  config.access_token        = BOT_ACCESS_TOKEN
  config.access_token_secret = BOT_ACCESS_TOKEN_SECRET
end
TweetStream.configure do |config|
  config.consumer_key       = BOT_CONSUMER_KEY
  config.consumer_secret    = BOT_CONSUMER_SECRET
  config.oauth_token        = BOT_ACCESS_TOKEN
  config.oauth_token_secret = BOT_ACCESS_TOKEN_SECRET
  config.auth_method        = :oauth
end
client = TweetStream::Client.new


def get_access_token
  access_token = nil
  auth_uri = URI.parse(AUTHORIZE_URL)
  https = Net::HTTP.new(auth_uri.host,443)
  https.use_ssl = true
  query_string= "grant_type=client_credentials&client_id=#{CGI.escape(CLIENT_ID)}&client_secret=#{CGI.escape(CLIENT_SECRET)}&scope=#{CGI.escape(SCOPE)}"
  response=https.post(auth_uri.path, query_string)
  json = JSON.parse(response.body)
  access_token = json['access_token']
end

def translate_text(text,from,to)
  access_token = get_access_token
  trans_uri=URI.parse(TRANSLATION_URL)
  http=Net::HTTP.new(trans_uri.host)
  res = http.get(trans_uri.path+"?from=#{from}&to=#{to}&text=#{URI.escape(text)}",'Authorization' => "Bearer #{access_token}")
  xml = REXML::Document.new(res.body)
  xml.root.text
end

@from=ENV["LANGUAGE_FROM"]
@to = ENV["LANGUAGE_TO"]
@mention_include = (ENV["MENTION_NOT_INCLUDE"]=="false")
@ids=ENV["USER_IDS"].split(/[, ]/).map(&:to_i)
client.follow(@ids) do |tweet|
  if @mention_include||(tweet.in_reply_to_user_id.class==Twitter::NullObject&&tweet.retweeted_status.class==Twitter::NullObject)
    twe=tweet.text
    urls = twe.scan(/https?:\/\/[\w\/:%#\$&\?\(\)~\.=\+\-]+/)
    urls.each{|url| twe=twe.gsub(url,"")}
    twe=translate_text(twe,@from,@to)
    tweets = twe.scan(/.{1,#{140}}/)
    while tweets.last.length<140-25 && urls.length>=1
      tweets.last << (" " + urls.shift)
    end
    if urls.length!=0
      tweets << urls.join(" ")
    end
    tweets.each do |twe|
      cli.update(twe)
    end
  end
end
