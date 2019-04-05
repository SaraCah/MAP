require_relative 'main'

def app
  MAPTheAPI
end

map "/" do
  run MAPTheAPI
end
