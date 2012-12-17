require 'sinatra'

get '/' do
  'Hello world!'
end

require './worker.rb'
