##
# evernote_oauth.rb
# Copyright 2010 Evernote Corporation. All rights reserved.
#
# This sample web application demonstrates the step-by-step process of using OAuth to
# authenticate to the Evernote web service. More information can be found in the
# Evernote API Overview at http://www.evernote.com/about/developer/api/evernote-api.htm.
#
# Note that we're not attempting to demonstrate Ruby/Sinatra best practices or
# build a scalable multi-user web application, we're simply giving you an idea
# of how the OAuth workflow works with Evernote.
#
# Note that the formalization of OAuth as RFC 5849 introduced some terminology changes.
# The comments in this sample code use the new (RFC) terminology, but most of the code
# itself still uses the old terms, which are also used by the OAuth RubyGem.
#
# Old term                    New Term
# --------------------------------------------------
# Consumer                    client
# Service Provider            server
# User                        resource owner
# Consumer Key and Secret     client credentials
# Request Token and Secret    temporary credentials
# Access Token and Secret     token credentials
#
# Requires the Sinatra framework and the OAuth RubyGem. You can install these
# components as follows:
#
#   gem install evernote-thrift
#   gem install sinatra
#   gem install oauth
#
# To run this application:
#
#   ruby -rubygems evernote_oauth.rb
#
# Sinatra will start on port 4567. You can view the sample application by visiting
# http://localhost:4567 in a browser.
##

require 'sinatra'
enable :sessions

# Load our dependencies and configuration settings
$LOAD_PATH.push(File.expand_path(File.dirname(__FILE__)))
require "evernote_config.rb"

##
# Verify that you have obtained an Evernote API key
##
before do
  if OAUTH_CONSUMER_KEY.empty? || OAUTH_CONSUMER_SECRET.empty?
    halt '<span style="color:red">Before using this sample code you must edit evernote_config.rb and replace OAUTH_CONSUMER_KEY and OAUTH_CONSUMER_SECRET with the values that you received from Evernote. If you do not have an API key, you can request one from <a href="http://dev.evernote.com/documentation/cloud/">dev.evernote.com/documentation/cloud/</a>.</span>'
  end
end

helpers do
  def auth_token
    session[:access_token].token if session[:access_token]
  end

  def client
    @client ||= EvernoteOAuth::Client.new(token: auth_token, consumer_key:OAUTH_CONSUMER_KEY, consumer_secret:OAUTH_CONSUMER_SECRET, sandbox: SANDBOX)
  end

  def user_store
    @user_store ||= client.user_store
  end

  def note_store
    @note_store ||= client.note_store
  end

  def en_user
    user_store.getUser(auth_token)
  end

  def total_note_count
    notebooks = note_store.listNotebooks(auth_token)
    notebooks.inject(0) do |total_count, notebook|
        filter = Evernote::EDAM::NoteStore::NoteFilter.new
        filter.notebookGuid = notebook.guid
        counts = note_store.findNoteCounts(auth_token, filter, false)
        total_count += counts.notebookCounts[notebook.guid]
      end
    end
  end

##
# Index page
##
get '/' do
  erb :example
end

##
# Reset the session
##
get '/reset' do
  session.clear
  redirect '/'
end

##
# Step 1: obtain temporary credentials
##
get '/requesttoken' do
  callback_url = request.url.chomp("requesttoken").concat("callback")

  begin
    session[:request_token] = client.authentication_request_token(:oauth_callback => callback_url)
    redirect '/authorize'
  rescue => e
    @last_error = "Error obtaining temporary credentials: #{e.message}"
    erb :error
  end
end

##
# Step 2a: redirect the user to Evernote for authoriation
##
get '/authorize' do
  if session[:request_token]
    redirect session[:request_token].authorize_url
  else
    # You shouldn't be invoking this if you don't have a request token
    @last_error = "Request token not set."
    erb :error
  end
end

##
# Step 2b: receive callback from the Evernote authorization page
##
get '/callback' do
  if params['oauth_verifier']
    session[:oauth_verifier] = params['oauth_verifier']
    redirect '/accesstoken'
  else
    @last_error = "Content owner did not authorize the temporary credentials"
    erb :error
  end
end

##
# Step 3: exchange the temporary credentials for token credentials
##
get '/accesstoken' do
  # You shouldn't be invoking this if you don't have a request token
  if session[:request_token]
    begin
      session[:access_token] = session[:request_token].get_access_token(:oauth_verifier => session[:oauth_verifier])

      # The response from the server will include the NoteStore URL that we
      # will use to access the user's notes, as well as some other handy variables
      session[:noteStoreUrl] = session[:access_token].params['edam_noteStoreUrl']
      session[:webApiUrlPrefix] = session[:access_token].params['edam_webApiUrlPrefix']
      session[:userId] = session[:access_token].params['edam_userId']

      # Convert from milliseconds since the the epoch to seconds with fractional part
      session[:tokenExpires] = session[:access_token].params['edam_expires']

      redirect '/list'
    rescue => e
      @last_error = "Failed to obtain token credentials: #{e.message}"
      erb :error
    end
  else
    redirect '/'
  end

end

##
# Step 4: access the user's Evernote account
##
get '/list' do
  begin
    # Get notebooks
    notebooks = client.note_store.listNotebooks(session[:access_token].token)
    session[:notebooks] = notebooks.map(&:name)

    # Get username
    session[:username] = en_user.username

    # Get total note count
    session[:total_notes] = total_note_count

  rescue => e
    @last_error = "Error listing notebooks: #{e.message}"
    erb :error
  end

  erb :example
end


__END__

@@ example
<html>
  <head>
    <title>Evernote Ruby Example App</title>
  </head>
  <body>
    <a href="/requesttoken">Click here</a> to authenticate this application using OAuth.
    <% if session[:notebooks] %>
    <hr />
    <h3>The current user is <%= session[:username] %> and there are <%= session[:total_notes] %> notes in their account</h3>
    <br />
    <h3>Here are the notebooks in this account:</h3>
      <ul>
      <% session[:notebooks].each do |notebook| %>
        <li><%= notebook %></li>
      <% end %>
    </ul>
    <% end %>
  </body>
</html>

@@ error 
<html>
  <head>
    <title>Evernote Ruby Example App &mdash; Error</title>
  </head>
  <body>
    <p>An error occurred: <%= @last_error %></p>
    <p>Please <a href="/reset">start over</a>.</p>
  </body>
</html>
