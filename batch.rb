# -*- coding: utf-8 -*-
require 'net/https'
require 'json'
require 'twitter'

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
  xs = JSON.parse(s).map {|json|
    created_at = json["created_at"]
    user = json["actor"]["login"]
    repo = json["repo"]["name"]
    type = json["type"].sub(/Event$/, "")
    content = "#{user}, #{repo}"
    url = ""

    payload = json["payload"]
    case type
    when "CommitComment"
      short_type = "CommitComment"
      url = payload["comment"]["html_url"]
    when "Create"
      short_type = "Create"
      ref_type = payload["ref_type"]
      content += "\n#{ref_type}"
      url = "https://github.com/#{repo}"
    when "Delete"
      short_type = "Delete"
      ref_type = payload["ref_type"]
      content += "\n#{ref_type}"
      url = "https://github.com/#{repo}"
    when "Fork"
      short_type = "Fork"
      full_name = payload["forkee"]["full_name"]
      content += "\n#{full_name}"
      url = payload["forkee"]["html_url"]
    when "Gollum"
      short_type = "Gollum"
      url = "https://github.com/#{repo}/wiki"
    when "IssueComment"
      short_type = "IssueComment"
      issue_title = payload["issue"]["title"]
      content += "\n\"#{issue_title}\""
      url = payload["comment"]["html_url"]
    when "Issues"
      short_type = "Issues"
      action = payload["action"]
      issue_title = payload["issue"]["title"]
      content += "\n#{action} \"#{issue_title}\""
      url = payload["issue"]["html_url"]
    when "Member"
      short_type = "Member"
      action = payload["action"]
      acted_user = payload["member"]["login"]
      content += "\n#{action} \"#{acted_user}\""
      url = "https://github.com/#{repo}"
    when "PullRequest"
      short_type = "PR"
      action = payload["action"]
      title = payload["pull_request"]["title"]
      content += "\n#{action} \"#{title}\""
      url = payload["pull_request"]["html_url"]
    when "PullRequestReviewComment"
      short_type = "PRReviewComment"
      action = payload["action"]
      pull_request_title = payload["pull_request"]["title"]
      content += "\n#{action} \"#{pull_request_title}\""
      url = payload["comment"]["html_url"]
    when "Push"
      short_type = "Push"
      before = payload["before"].slice(0, 10)
      head = payload["head"].slice(0, 10)
      url = "https://github.com/#{repo}/compare/#{before}...#{head}"
    when "Release"
      short_type = "Release"
      action = payload["action"]
      tag_name = payload["release"]["tag_name"]
      content += "\n#{action} \"#{tag_name}\""
      url = payload["release"]["html_url"]
    when "TeamAdd"
      short_type = "TeamAdd"
      team_name = payload["team"]["name"]
      content += "\n#{team_name}"
      url = "https://github.com/#{repo}"
    when "Watch"
      short_type = "Watch"
      action = payload["action"]
      content += "\n#{action}"
      url = "https://github.com/#{repo}"
    end
    {
      created_at: created_at,
      content: "#{created_at} [#{short_type}]\n#{content}",
      url: url
    }
  }
  xs.reverse
end

def new_twitter_client
  twitter_consumer_key = ENV['TWITTER_CONSUMER_KEY']
  twitter_consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
  twitter_access_token = ENV['TWITTER_ACCESS_TOKEN']
  twitter_access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']

  Twitter::REST::Client.new do |config|
    config.consumer_key        = twitter_consumer_key
    config.consumer_secret     = twitter_consumer_secret
    config.access_token        = twitter_access_token
    config.access_token_secret = twitter_access_token_secret
  end
end

def tweet(twitter_client, content)
  twitter_client.update(content)
end

def read_previous_created_at(twitter_client)
  timeline = twitter_client.home_timeline
  if timeline.empty?
    '2000-01-01T00:00:00Z'
  else
    timeline.first.text.split(' ').first
  end
end



response = download_events
if response.code.to_i == 200
  twitter_client = new_twitter_client
  previous_created_at = read_previous_created_at(twitter_client)
  events =
    to_array(response.body).reject {|event|
      event.nil?
    }.select {|event|
      previous_created_at.nil? ||
        (DateTime.parse(event[:created_at]) > DateTime.parse(previous_created_at))
    }
  tco_length = 23 # t.co length
  lf_length = 2  # \n length
  text_limit_size = 140 - tco_length - lf_length
  events.each {|event|
    text =
      if event[:content].size > text_limit_size
        n = event[:content].size - text_limit_size
        event[:content][0, event[:content].size - n] + "\n" + event[:url]
      else
        event[:content] + "\n" + event[:url]
      end
    tweet(twitter_client, text)
  }
else
  raise "GitHub API Error. http_status_code: #{response.code}"
end

