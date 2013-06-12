require 'JSONable'

class NoteView
	attr_accessor :title, :content
	def initialize(title, content)
		@title = title
		@content = content
	end
end