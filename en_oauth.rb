##
# Copyright 2012 Evernote Corporation. All rights reserved.
##

require 'sinatra'
require 'json'
enable :sessions

# Load our dependencies and configuration settings
$LOAD_PATH.push(File.expand_path(File.dirname(__FILE__)))
require "evernote_config.rb"
require "notebook_view"
require "note_view"

##
# Verify that you have obtained an Evernote API key
##
before do
  if OAUTH_CONSUMER_KEY_FULL.empty? || OAUTH_CONSUMER_SECRET_FULL.empty?
    halt '<span style="color:red">Before using this sample code you must edit evernote_config.rb and replace OAUTH_CONSUMER_KEY and OAUTH_CONSUMER_SECRET with the values that you received from Evernote. If you do not have an API key, you can request one from <a href="http://dev.evernote.com/documentation/cloud/">dev.evernote.com/documentation/cloud/</a>.</span>'
  end
end

helpers do
  def auth_token
    session[:access_token].token if session[:access_token]
  end

  def client
    @client ||= EvernoteOAuth::Client.new(token: auth_token, consumer_key:OAUTH_CONSUMER_KEY_FULL, consumer_secret:OAUTH_CONSUMER_SECRET_FULL, sandbox: SANDBOX)
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

  def notebooks
    @notebooks ||= note_store.listNotebooks(auth_token)
  end

  def public_notebooks(userId, uri)
    user_info = user_store.getPublicUserInfo(userId)
    puts userId
    puts user_info.userId
    @public_notebooks ||= note_store.getPublicNotebook(user_info.userId, uri)
    puts 'vuelve'
    puts @public_notebooks
    @public_notebooks
  end

  def total_note_count
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    counts = note_store.findNoteCounts(auth_token, filter, false)
    notebooks.inject(0) do |total_count, notebook|
      total_count + (counts.notebookCounts[notebook.guid] || 0)
    end
  end

  def default_note
    note = Evernote::EDAM::Type::Note.new
    note.title = 'Default note title'
    note.content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">" +
    "<en-note>Hello world!!</en-note>"
    note
  end

  def notebook_notes(id)
    puts id
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    filter.notebookGuid = id
    resultSpec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
    note_store.findNotesMetadata(auth_token, filter, 0, 25, resultSpec)
  end

end

##
# Index page
##
get '/' do
  erb :index
end

##
# Reset the session
##
get '/reset' do
  session.clear
  redirect '/'
end

##
# Obtain temporary credentials
##
get '/requesttoken' do
  callback_url = request.url.chomp("requesttoken").concat("callback")
  begin
    session[:request_token] = client.request_token(:oauth_callback => callback_url)
    redirect '/authorize'
  rescue => e
    @last_error = "Error obtaining temporary credentials: #{e.message}"
    erb :error
  end
end

##
# Redirect the user to Evernote for authoriation
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
# Receive callback from the Evernote authorization page
##
get '/callback' do
  unless params['oauth_verifier'] || session['request_token']
    @last_error = "Content owner did not authorize the temporary credentials"
    halt erb :error
  end
  session[:oauth_verifier] = params['oauth_verifier']
  begin
    session[:access_token] = session[:request_token].get_access_token(:oauth_verifier => session[:oauth_verifier])
    redirect '/list'
  rescue => e
    @last_error = 'Error extracting access token'
    erb :error
  end
end


##
# Access the user's Evernote account and display account data
##
get '/list' do
  begin
    public_notebook = public_notebooks('olareoun', 'mipublicnotebook')
    puts public_notebook.publishing.uri
    session[:public] = NotebookView.new(public_notebook.guid, public_notebook.name)
    session[:notebooks] = notebooks.map{|notebook| NotebookView.new(notebook.guid, notebook.name)}
    session[:username] = en_user.username
    erb :index
  rescue => e
    @last_error = "Error listing notebooks: #{e.message}"
    erb :error
  end
end

get '/create' do
  begin
    note_store.createNote(auth_token, default_note)
    redirect '/list'
  rescue
    @last_error = 'Error creating note'
    erb :error
  end
end

get '/getNote' do
  @notes = notebook_notes(params['id']).notes.collect { |note| note_store.getNote(auth_token, note.guid, true, true, false, false) }
  @notes = @notes.map{|note| NoteView.new(note.title, note.content)}
  puts @notes[0].instance_variables.to_json
  puts JSON.fast_generate @notes
  erb :note
end


__END__

@@ note
<html>
<head>
  <title>Evernote Ruby Example App</title>
</head>
<body>
  <% if @notes %>
  <% @notes %>
  <br />
  <h3>Here are the notes:</h3>
    <% @notes.each do |note| %>
      <div>
        <h4><%= note.title %></h4>
        <p><%= note.content %></p>
      </div>
    <% end %>
  <% end %>
</body>
</html>

@@ index
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
    <li><%= notebook.name %> - <a href="/getNote?id=<%= notebook.id %>">get notes</a></li>
    <% end %>
  </ul>
  <% end %>
  <% if session[:public] %>
  <br />
  <h3>Here are the PUBLIC notebooks in this account:</h3>
  <ul>
    <li><%= session[:public].name %> - <a href="/getNote?id=<%= session[:public].id %>">get notes</a></li>
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
