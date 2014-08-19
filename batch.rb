# -*- coding: utf-8 -*-
require 'net/https'
require 'json'
require 'twitter'
require 'redis'
require 'date'

def download_events
  github_oauth_token = ENV['GITHUB_OAUTH_TOKEN']
  github_user = ENV['GITHUB_USER']
  https = Net::HTTP.new('api.github.com',443)
  https.use_ssl = true
  https.start {
    https.get("/users/#{github_user}/received_events?access_token=#{github_oauth_token}")
  }
end

def to_array(s)
  JSON.parse(s).map {|json|
    created_at = json["created_at"]
    user = json["actor"]["login"]
    repo = json["repo"]["name"]
    type = json["type"].sub(/Event$/, "")
    content = "#{user}, #{repo}"
    url = ""

    payload = json["payload"]
    case type
    when "CommitComment"
      short_type = "[CC]"
      content = short_type + content
      url = payload["comment"]["html_url"]
    when "Create"
      short_type = "[C]"
      ref_type = payload["ref_type"]
      content = short_type + content + "\n#{ref_type}"
      url = "https://github.com/#{repo}"
    when "Delete"
      short_type = "[D]"
      ref_type = payload["ref_type"]
      content = short_type + content + "\n#{ref_type}"
      url = "https://github.com/#{repo}"
    when "Fork"
      short_type = "[F]"
      full_name = payload["forkee"]["full_name"]
      content = short_type + content + "\n#{full_name}"
      url = payload["forkee"]["html_url"]
    when "Gollum"
      short_type = "[G]"
      content = short_type + content
      url = "https://github.com/#{repo}/wiki"
    when "IssueComment"
      short_type = "[IC]"
      issue_title = payload["issue"]["title"]
      content = short_type + content + "\n\"#{issue_title}\""
      url = payload["comment"]["html_url"]
    when "Issues"
      short_type = "[I]"
      action = payload["action"]
      issue_title = payload["issue"]["title"]
      content = short_type + content + "\n#{action}\n\"#{issue_title}\""
      url = payload["issue"]["html_url"]
    when "Member"
      short_type = "[M]"
      action = payload["action"]
      acted_user = payload["member"]["login"]
      content = short_type + content + "\n#{action}\n#{acted_user}"
      url = "https://github.com/#{repo}"
    when "PullRequest"
      short_type = "[PR]"
      action = payload["action"]
      title = payload["pull_request"]["title"]
      content = short_type + content + "\n#{action}\n\"#{title}\""
      url = payload["pull_request"]["html_url"]
    when "PullRequestReviewComment"
      short_type = "[PRRC]"
      action = payload["action"]
      pull_request_title = payload["pull_request"]["title"]
      content = short_type + content + "\n#{action}\n\"#{pull_request_title}\""
      url = payload["comment"]["html_url"]
    when "Push"
      short_type = "[P]"
      before = payload["before"].slice(0, 10)
      head = payload["head"].slice(0, 10)
      content = short_type + content
      url = "https://github.com/#{repo}/compare/#{before}...#{head}"
    when "Release"
      short_type = "[R]"
      action = payload["action"]
      tag_name = payload["release"]["tag_name"]
      content = short_type + content + "\n#{action}\n#{tag_name}"
      url = payload["release"]["html_url"]
    when "TeamAdd"
      short_type = "[T]"
      team_name = payload["team"]["name"]
      content = short_type + content + "\n#{team_name}"
      url = "https://github.com/#{repo}"
    when "Watch"
      short_type = "[W]"
      action = payload["action"]
      content = short_type + content + "\n#{action}"
      url = "https://github.com/#{repo}"
    end
    {
      created_at: created_at,
      content: content,
      url: url
    }
  }
end

def tweet(content)
  twitter_consumer_key = ENV['TWITTER_CONSUMER_KEY']
  twitter_consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
  twitter_access_token = ENV['TWITTER_ACCESS_TOKEN']
  twitter_access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']

  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = twitter_consumer_key
    config.consumer_secret     = twitter_consumer_secret
    config.access_token        = twitter_access_token
    config.access_token_secret = twitter_access_token_secret
  end
  client.update(content)
end

def read_previous_created_at
  begin
    redis.get "last_event_created_at"
  rescue
    if File.exist?("last_event_created_at")
      File.open("last_event_created_at") {|f|
        f.read
      }
    else
      nil
    end
  end
end

def save_last_created_at(created_at)
  unless created_at.nil?
    begin
      redis.set "last_event_created_at", created_at
    rescue
      File.write("last_event_created_at", created_at)
    end
  end
end

def redis
  if ENV["REDISTOGO_URL"].nil?
    Redis.new host:"127.0.0.1", port:"6379"
  else
    uri = URI.parse(ENV["REDISTOGO_URL"])
    Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end
end



response = download_events
if response.code.to_i == 200
  previous_created_at = read_previous_created_at
  events =
    to_array(response.body).reject {|event|
      event.nil?
    }.select {|event|
      f = "%Y-%m-%dT%H:%M:%SZ"
      previous_created_at.nil? ||
        (Date.strptime(event[:created_at], f) > Date.strptime(previous_created_at, f))
    }
  events.each {|event|
    url_limit = 23 # t.co length
    lf_length = 2  # \n length
    s =
      if event[:content].size > (140 - url_limit - lf_length)
        n = event[:content].size - (140 - url_limit - lf_length)
        event[:content][0, event[:content].size - n] + "\n" + event[:url]
      else
        event[:content] + "\n" + event[:url]
      end
    tweet(s)
  }
  save_last_created_at(events.first[:created_at]) unless events.empty?
else
  raise "GitHub API Error. http_status_code: #{response.code}"
end

