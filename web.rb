# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'
require 'erb'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    twitter_variables = %w[
      TWITTER_CONSUMER_KEY
      TWITTER_CONSUMER_SECRET
      TWITTER_ACCESS_TOKEN
      TWITTER_ACCESS_TOKEN_SECRET
    ]
    twitter_list = twitter_variables.map {|x|
      {
        name: x,
        status: !ENV[x].nil?
      }
    }

    github_variables = %w[
      GITHUB_OAUTH_TOKEN
      GITHUB_USER
    ]
    github_list = github_variables.map {|x|
      {
        name: x,
        status: !ENV[x].nil?
      }
    }

    redis_list = [
      {
        name: "REDISTOGO_URL",
        status: !ENV["REDISTOGO_URL"].nil?
      }
    ]

    @list = [
      {label: "Twitter", list: twitter_list},
      {label: "GitHub", list: github_list},
      {label: "Redis", list: redis_list}
    ]
    erb :index
  end
end

