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
      TWITTER_CONSUMER_KEY_FOR_GITHUB
      TWITTER_CONSUMER_SECRET_FOR_GITHUB
      TWITTER_ACCESS_TOKEN_FOR_GITHUB
      TWITTER_ACCESS_TOKEN_SECRET_FOR_GITHUB
    ]
    twitter_list = twitter_variables.map {|x|
      {
        name: x,
        status: !ENV[x].nil?
      }
    }

    github_variables = %w[
      GITHUB_USER
      GITHUB_PERSONAL_ACCESS_TOKEN
    ]
    github_list = github_variables.map {|x|
      {
        name: x,
        status: !ENV[x].nil?
      }
    }

    @list = [
      {label: "Twitter", list: twitter_list},
      {label: "GitHub", list: github_list}
    ]
    erb :index
  end
end

