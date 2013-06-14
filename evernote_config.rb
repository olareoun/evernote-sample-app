# Load libraries required by the Evernote OAuth sample applications
require 'oauth'
require 'oauth/consumer'

# Load Thrift & Evernote Ruby libraries
require "evernote_oauth"

# Client credentials
# Fill these in with the consumer key and consumer secret that you obtained
# from Evernote. If you do not have an Evernote API key, you may request one
# from http://dev.evernote.com/documentation/cloud/
OAUTH_CONSUMER_KEY = "olareoun"
OAUTH_CONSUMER_SECRET = "de27bae3bc64df82"

OAUTH_CONSUMER_KEY_FULL = "olareoun-1256"
OAUTH_CONSUMER_SECRET_FULL = '1cb959efa75b2e96'

SANDBOX = true

DEVELOPER_TOKEN = "S=s1:U=69109:E=14695b47846:C=13f3e034c4a:P=1cd:A=en-devtoken:V=2:H=384b266bbb66bbb852f6f389832297cb"
NOTESTORE_URL = "https://sandbox.evernote.com/shard/s1/notestore"

EVERNOTE_DEVELOPER_TOKEN = "S=s256:U=2ce05fb:E=14699a3d278:C=13f41f2a67b:P=1cd:A=en-devtoken:V=2:H=6a9d5faf401a355eabaa96dfae32ef95"
EVERNOTE_NOTESTORE_URL = "https://www.evernote.com/shard/s256/notestore"

EVERNOTE_HOST = "https://sandbox.evernote.com"
