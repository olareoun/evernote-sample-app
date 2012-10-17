require 'rubygems'
require 'sinatra'
require 'json'
require 'omniauth'
require 'omniauth-evernote'
require 'evernote-thrift'

class SinatraApp < Sinatra::Base

  HOST = "sandbox.evernote.com"
  ENURL = "https://#{HOST}"

  helpers do
    def makeUserStoreInstance
      userStoreUrl = "#{ENURL}/edam/user"
      userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
     end

    def makeNoteStoreInstance(userStore)
      noteStoreUrl = userStore.getNoteStoreUrl(session[:authtoken])
      noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    end

    def getTotalNoteCount(noteStore)
      totalCount = 0
      notebooks = noteStore.listNotebooks(session[:authtoken])
      notebooks.each do |notebook|
        filter = Evernote::EDAM::NoteStore::NoteFilter.new()
        filter.notebookGuid = notebook.guid
        counts = noteStore.findNoteCounts(session[:authtoken], filter, false)
        totalCount += counts.notebookCounts[notebook.guid]
      end
      totalCount
    end
  end

  configure do
    set :sessions, true
    set :inline_templates, true
  end

  use OmniAuth::Builder do
    provider :evernote, 'inkedmn', 'aa273e653c2dbebc', :client_options => { :site => "#{ENURL}" }
  end

  get '/' do
    erb "<h1>Login with evernote</h1><a href='/auth/evernote' class='btn btn-primary'>Login</a>"
  end

  get '/auth/:provider/callback' do
    session[:authtoken] = request.env['omniauth.auth']['credentials']['token']
    erb "<h1>#{params[:provider]}</h1>
      <pre>#{JSON.pretty_generate(request.env['omniauth.auth'])}</pre>
      <h4>#{session[:authtoken]}</h4>
	    <a href='/logout' class='btn'>Logout</a>
      <a href='/info' class='btn'>Get Account Info</a>"
  end

  get '/auth/failure' do
    erb "<h1>Authentication Failed:</h1><h3>message:<h3> <pre>#{params}</pre>
	 <a href='/' class='btn'>Start over</a>"
  end

  get '/info' do
    if session[:authtoken].empty?
      redirect '/'
    else
      userStore = makeUserStoreInstance
      ourUser = userStore.getUser(session[:authtoken])
      noteStore = makeNoteStoreInstance(userStore)
      totalCount = getTotalNoteCount(noteStore)
      erb "<h3>The authenticated user is #{ourUser.username}</h3>
      <p>There are #{totalCount} notes in this account.</p>"
    end
  end

  get '/logout' do
    session.clear
    redirect '/'
  end

end

SinatraApp.run! if __FILE__ == $0

__END__

@@ layout
<html>
  <head>
    <link href='http://twitter.github.com/bootstrap/assets/css/bootstrap.css' rel='stylesheet' />
  </head>
  <body>
    <div class='container'>
      <div class='content'>
        <%= yield %>
      </div>
    </div>
  </body>
</html>
