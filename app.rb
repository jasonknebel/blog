require 'sinatra'
require 'sinatra/activerecord'
require 'slim'
require 'will_paginate'
require 'will_paginate/active_record'
require 'redcarpet' #markdown
require 'uri'

#--------------------Setup--------------------#

class Post < ActiveRecord::Base
end

use Rack::MethodOverride

configure :development do
  set :database, 'sqlite3:///db/blog_development.sqlite3'
  require 'rack-livereload'
  require 'sinatra/reloader'
  use Rack::LiveReload
end


configure :production do
  db = URI.parse(ENV['HEROKU_POSTGRESQL_JADE_URL'])

  ActiveRecord::Base.establish_connection(
    :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
    :host     => db.host,
    :port     => db.port,
    :username => db.user,
    :password => db.password,
    :database => db.path[1..-1],
    :encoding => 'unicode',
    :pool => 5
  )
end

#--------------------Helpers--------------------#

helpers do

  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && 
      @auth.credentials == ['admin', 'admin']
  end

  def markdown(text)
    Redcarpet::Markdown.new(Redcarpet::Render::HTML).render(text)
  end

  def seo_title(text)
    text.downcase.gsub(/[^a-z0-9]+/i, '-')
  end

  def truncate(text, post_url, max_length)
    address = "...<a href='/show/#{post_url}'>[show full post]</a>"
    text.length > max_length ? text[0..max_length] + address : text
  end

end

#--------------------Routes--------------------#

get '/' do 
  @posts = Post.where('published_at IS NOT NULL').order('published_at DESC').page(params[:page]).per_page(5)
  slim :index 
end

get '/show/:url' do
  @post = Post.find_by_url(params[:url])
  slim :show
end

#----------Admin----------#

get '/admin' do
  protected!
  @posts = Post.order('published_at DESC, created_at DESC').page(params[:page]).per_page(10)
  slim :admin
end

#-----New_Post-----#

post '/admin/new' do
  slim :new 
end

put '/admin/new' do 
  if (params[:title].empty? || params[:content].empty?)
    "You didn't enter something."
  else
    Post.create( title: params[:title], content: params[:content],
      url: seo_title(params[:title].to_s))
    redirect '/admin'
  end
end

#-----Edit_Post-----#

post '/admin/edit/:id' do
  @post = Post.find(params[:id])
  slim :edit
end

put '/admin/edit/:id' do
  Post.find(params[:id]).update_attributes(title: params[:edit_title], 
    content: params[:edit_content], url: seo_title(params[:edit_title].to_s))
  redirect '/admin'
end

#-----Delete_Post-----#

delete '/admin/:id' do
  Post.find(params[:id]).destroy
  redirect '/admin'
end

#-----Publish_Post-----#

put '/admin/publish/:id' do
  Post.find(params[:id]).update_attributes(published_at: Time.now)
  redirect '/admin'
end

get '/post/:id' do
  @post = Post.find(params[:id])
  slim :show
end