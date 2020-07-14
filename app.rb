require "sinatra"
require_relative "authentication.rb"

require 'stripe'

set :publishable_key, 'pk_test_fRyXDvymfCOzkredf4eOCLF7'
set :secret_key, 'sk_test_h4aJvjJOodQxj2nadXNXHRSC'

Stripe.api_key = settings.secret_key

set :session_secret, 'FDIUJp9fdij@#@D#5*9P*DFJ9pJDFSP(*#'

# need install dm-sqlite-adapter
# if on heroku, use Postgres database
# if not use sqlite3 database I gave you
if ENV['DATABASE_URL']
  DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
else
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/app.db")
end

class Video
	include DataMapper::Resource

	property :id, Serial
	#fill in the rest
	property :title, Text
	property :description, Text
	property :video_url, Text
	property :pro, Boolean, :default => false
end

DataMapper.finalize
User.auto_upgrade!
Video.auto_upgrade!

#make an admin user if one doesn't exist!
if User.all(administrator: true).count == 0
	u = User.new
	u.email = "admin@admin.com"
	u.password = "admin"
	u.administrator = true
	u.save
end

#the following urls are included in authentication.rb
# GET /login
# GET /logout
# GET /sign_up
def youtube_embed(youtube_url)
  if youtube_url[/youtu\.be\/([^\?]*)/]
    youtube_id = $1
  else
    # Regex from # http://stackoverflow.com/questions/3452546/javascript-regex-how-to-get-youtube-video-id-from-url/4811367#4811367
    youtube_url[/^.*((v\/)|(embed\/)|(watch\?))\??v?=?([^\&\?]*).*/]
    youtube_id = $5
  end

  %Q{<iframe title="YouTube video player" width="640" height="390" src="https://www.youtube.com/embed/#{ youtube_id }" frameborder="0" allowfullscreen></iframe>}
end

def is_admin?
	if !current_user || !current_user.administrator
		redirect "/"
	end
end

def free_only!
	authenticate!
	if current_user.pro || current_user.administrator
		redirect '/'
	end
end
# authenticate! will make sure that the user is signed in, if they are not they will be redirected to the login page
# if the user is signed in, current_user will refer to the signed in user object.
# if they are not signed in, current_user will be nil

get "/" do
	erb :index
end
get "/videos" do
	authenticate!
	if current_user.pro || current_user.administrator
		@videos = Video.all
	
	else
		@videos = Video.all(pro: false)
	end
	erb :videos
#	output = ""
#	Video.all.each do |v|
#		if v.pro != true
#			output += v.title + "<br/>"
#			output += v.description += "<br/>"
#			output += "<embed src=" + v.video_url + " allowfullscreen=\"true\" width=\"425\" height=\"344\">"
#		end
#	end
#	return output
end

post "/videos/create" do
	is_admin?
	erb :createvid
end

get '/videos/new' do
	is_admin?
	erb :new_videos
	#submit this form info to post/videos/create
end

get '/upgrade' do
	free_only!
	#if !current_user.pro || !current_user.administrator
		erb :upg
	#else
	#	redirect "/videos"
	#end
end

post '/charge' do

	free_only!

	begin
	# Amount in cents
  @amount = 500

  customer = Stripe::Customer.create(
    :email => 'customer@example.com',
    :source  => params[:stripeToken]
  )

  charge = Stripe::Charge.create(
    :amount      => @amount,
    :description => 'Sinatra Charge',
    :currency    => 'usd',
    :customer    => customer.id
  )

  	current_user.pro = true
	current_user.save
  	erb :charge

rescue
	erb :paymen_failed
end
end