# -*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    "Hello World!"
  end
end

